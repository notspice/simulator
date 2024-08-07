const std = @import("std");

const Simulator = @import("../simulator.zig").Simulator;
const NodeIndex = @import("../simulator.zig").NodeIndex;
const errors = @import("../utils/errors.zig");
const stringutils = @import("../utils/stringutils.zig");
const gate = @import("../logic/gate.zig");
const node = @import("../logic/node.zig");
const module = @import("../logic/module.zig");

const TokenType = enum {
    Keyword,
    Statement,
    Separator,
    OpenBracket,
    CloseBracket,
    OpenSquare,
    CloseSquare,
};

/// Takes the text representation of the netlist and transforms it into appropriately connected Nodes and Gates
pub fn parseNetlist(sim: *Simulator, text_netlist: [*:0]const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!void {
    // Convert 0-terminated string to a Zig slice.
    const text_netlist_length = std.mem.len(text_netlist);
    const text_netlist_slice = text_netlist[0..text_netlist_length];

    // Separate the input text into lines.
    var lines = std.mem.tokenizeAny(u8, text_netlist_slice, "\n");
    var line_num: usize = 0;

    var inside_module: bool = false;
    var inside_inputs: bool = false;
    var after_inputs: bool = false;
    var keyword_instance: bool = false; // For handling special instances like @IN etc.
    var current_module: ?module.Module = null; // Store the module it's currently parsing
    // Iterate over the lines and tokenize all words
    while (lines.next()) |line| : (line_num += 1) {
        var words = std.mem.tokenizeAny(u8, line, " ");
        keyword_instance = false;

        var instance_name: []const u8 = "";
        var instance_inputs: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(alloc);
        var instance_outputs: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(alloc);
        
        var index: usize = 0;
        while (words.next()) |word| : (index += 1) {
            const token = try categorize(word, line_num);

            if (index == 0 and token == TokenType.Keyword and inside_module) keyword_instance = true;
            if (inside_module and !inside_inputs and token == TokenType.Separator) inside_inputs = true // Enter instance
            else if (inside_inputs and token == TokenType.Separator) {
                inside_inputs = false;
                after_inputs = true;
            } // Instance end

            if (!inside_module and token == TokenType.CloseBracket) return errors.ParserError.UnexpectedBracket;
            if (inside_module and token == TokenType.OpenBracket) return errors.ParserError.UnexpectedBracket;

            if (token == TokenType.OpenBracket) inside_module = true;
            if (token == TokenType.CloseBracket) inside_module = false;

            if (words.peek()) |next_word| {
                if (try isTokenAllowed(token, try categorize(next_word, line_num), inside_module, inside_inputs)) {
                    if (!inside_module and token == TokenType.Keyword) { // Module definition
                        // std.debug.print("name: {s}, type: {s}\n", .{ next_word, word[1..word.len] });
                        var type_lower = try alloc.alloc(u8, word.len - 1);
                        var i: usize = 0;
                        for (word[1..word.len]) |char| {
                            type_lower[i] = std.ascii.toLower(char);
                            i += 1;
                        }
                        defer alloc.free(type_lower);

                        var module_type = module.ModuleType.Top;

                        if (std.mem.eql(u8, type_lower, "top")) {
                            module_type = module.ModuleType.Top;
                        } else if (std.mem.eql(u8, type_lower, "module")) {
                            module_type = module.ModuleType.Sub;
                        } else if (std.mem.eql(u8, type_lower, "comb")) {
                            module_type = module.ModuleType.SubCombinational;
                        } else {
                            return errors.ParserError.UnknownModuleType;
                        }

                        if (current_module) |to_add| {
                            try sim.add_module(to_add);
                        }
                        current_module = try module.Module.init(alloc, module_type, next_word);
                    }

                    if (inside_module) {
                        const next_token = try categorize(next_word, 0);
                        if (!inside_inputs and (next_token == TokenType.Separator)) { // The instance type (eg. >>AND<< : in_1 in_2 ...)
                            if (instance_name.len > 0) return errors.ParserError.UnexpectedCharacter; // Instance beginning on top of another instance
                            instance_name = word;
                        }

                        if (inside_inputs and (next_token != TokenType.Separator)) try instance_inputs.append(next_word);
                        if (after_inputs and (next_token != TokenType.Separator)) try instance_outputs.append(next_word);
                    }
                } else return errors.ParserError.UnexpectedCharacter;
            }
        }
        if (keyword_instance and inside_inputs) inside_inputs = false;
        std.debug.print("{s}\n", .{instance_name});

        if (keyword_instance) {

        } else {
            if (instance_name.len == 0 and instance_inputs.items.len == 0 and instance_outputs.items.len == 0) continue;

            const instance_name_pascal = try stringutils.pascal(instance_name, alloc);
            defer alloc.free(instance_name_pascal);

            // Parse the instance_name_pascal string into a GateType enum variant
            const gate_type: gate.GateType = loop: inline for (@typeInfo(gate.GateType).Enum.fields) |field| {
                if (std.mem.eql(u8, field.name, instance_name_pascal)) {
                    break :loop @enumFromInt(field.value);
                }
            } else {
                return errors.ParserError.InvalidGateInstanceName;
            };

            try current_module.?.add_gate(alloc, gate_type, instance_inputs, instance_outputs);
        }
    }

    if (inside_module) return errors.ParserError.MissingBracket;
}

fn categorize(word: []const u8, _: usize) (errors.ParserError)!TokenType {
    const separators: [2][]const u8 = .{ ":", "->" };
    
    const open_bracket: u8 = '{';
    const close_bracket: u8 = '}';

    const open_suqare: u8 = '[';
    const close_square: u8 = ']';

    // Built-in declatation, eg. @MODULE
    if (std.mem.startsWith(u8, word, "@")) {
        for (word[1..word.len]) |letter| {
            if (!std.ascii.isAlphanumeric(letter)) return errors.ParserError.KeywordNotAlphanumeric;
        }
        return TokenType.Keyword;
    }

    for (separators) |separator| {
        if (std.mem.eql(u8, separator, word)) return TokenType.Separator;
    }

    if (word.len == 1) {
        return switch (word[0]) {
            open_bracket => TokenType.OpenBracket,
            close_bracket => TokenType.CloseBracket,
            open_suqare => TokenType.OpenSquare,
            close_square => TokenType.CloseSquare,
            else => TokenType.Statement
        };
    }

    return TokenType.Statement;
}

fn isTokenAllowed(token: TokenType, next_token: TokenType, inside_module: bool, inside_inputs: bool) (errors.ParserError)!bool {
    // FIXME: Support square brackets
    return switch (token) {
        TokenType.Keyword => {
            return (!inside_module and next_token == TokenType.Statement) or // Expect statement after a keyword outside a module (eg. @MODULE >>modulename<< ...)
                    (inside_module and next_token == TokenType.Separator); // Expect separator after a keyword in a module (eg. @IN >>:<< in_1 in_2)
        },
        TokenType.Statement => {
            if (inside_module) {
                if (next_token == TokenType.CloseBracket) return true; // Inside module expect a closing bracket (eg. AND : in_1 in_2 -> out_1 out_2 >>}<<)
                if (!inside_inputs and (next_token == TokenType.Separator)) return true; // Inside a module, but outside any instance, expect a separator (eg. ADD >>:<< in_1 in_2 ...)
                if (inside_inputs and (next_token == TokenType.Statement or next_token == TokenType.Separator)) return true; // Inside a module and an instance, expect another statement or a separator (eg. ADD : in_1 >>in_2<< ...)
            } else {
                return (next_token == TokenType.OpenBracket); // Outside a module and after a statement, expect an opening bracket (eg. @MODULE test >>{<<)
            }
            return errors.ParserError.UnexpectedCharacter; // Unreachable, in theory...
        },
        TokenType.Separator => {
            return next_token == TokenType.Statement; // Expecting a statement after a separator (eg. ADD : >>in_1<< in_2 ...)
        },
        TokenType.OpenBracket => {
            return !inside_module and (next_token == TokenType.Statement or next_token == TokenType.Keyword); // Expect a statement or a keyword after an opening bracket, just for inlining purposes (eg. @MODULE test { >>@IN<< ...})
        },
        TokenType.CloseBracket => {
            return inside_module and next_token == TokenType.Keyword; // Just in case someone defines a module in the same line (eg. } >>@MODULE<< anothermodule ...)
        },
        else => false,
    };
}
