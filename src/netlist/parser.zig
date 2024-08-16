const std = @import("std");

const Simulator = @import("../simulator.zig").Simulator;
const NodeIndex = @import("../simulator.zig").NodeIndex;
const errors = @import("../utils/errors.zig");
const stringutils = @import("../utils/stringutils.zig");
const gate = @import("../logic/gate.zig");
const node = @import("../logic/node.zig");
const module = @import("../logic/module.zig");
const directive = @import("./directive.zig");

const TokenType = enum {
    Keyword,
    Statement,
    Separator,
    OpenBracket,
    CloseBracket,
    OpenSquare,
    CloseSquare,
    Semicolon,
};

/// Takes the text representation of the netlist and transforms it into appropriately connected Nodes and Gates
pub fn parseNetlist(simulator: *Simulator, text_netlist: []const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!void {
    // Separate the input text into lines.
    var lines = std.mem.tokenizeAny(u8, text_netlist, "\n");
    var line_num: usize = 0;

    var inside_module:    bool = false; // Interpreting the contents of a module
    var inside_instance:  bool = false; // Interpreting the second section of the instance
    var after_inputs:     bool = false; // Interpreting the last section of the instance
    var keyword_instance: bool = false; // For handling special instances like @IN etc.

    // Object being currently initialized
    var current_module: std.ArrayList([]const u8) = std.ArrayList([]const u8).init(alloc);

    // Iterate over the lines and tokenize all words
    while (lines.next()) |line| : (line_num += 1) {
        var words = std.mem.tokenizeAny(u8, line, " ");
        keyword_instance = false;
        
        var index: usize = 0;
        while (words.next()) |word| : (index += 1) {
            const token = try categorize(word, line_num);

            if (index == 0 and token == TokenType.Keyword) {
                keyword_instance = true;
            }

            if (!inside_module and token == TokenType.Keyword) {
                if (current_module.items.len > 0) try handleModule(simulator, &current_module, alloc);
                current_module.deinit();
                current_module = std.ArrayList([]const u8).init(alloc);
            }

            if (token == TokenType.CloseBracket) inside_module = false;
            if (inside_module and !std.mem.endsWith(u8, line, ";")) return errors.ParserError.MissingSemicolon;
            if (token == TokenType.OpenBracket) inside_module = true;

            if (inside_module and !inside_instance and token == TokenType.Separator) inside_instance = true // Enter instance
            else if (inside_instance and token == TokenType.Separator) {
                inside_instance = false;
                after_inputs = true;
            } // Instance end

            if (words.peek()) |next_word| {
                // std.debug.print("w: {s} nw: {s} t: {s} im: {?} ii: {?}\n", .{ word, next_word, @tagName(token), inside_module, inside_instance});
                const next_token = try categorize(next_word, line_num);
                if (try isTokenAllowed(token, next_token, inside_module, inside_instance)) {
                    try current_module.append(word);
                } else return errors.ParserError.UnexpectedCharacter;
            } else {
                try current_module.append(word);
            }
        }
        if (keyword_instance and inside_instance) inside_instance = false;
    }

    if (inside_module) return errors.ParserError.MissingBracket; // If the `inside_module` is still true, it has not been set to `false` by the closing bracket detection
    if (current_module.items.len > 0) try handleModule(simulator, &current_module, alloc);
    current_module.deinit();
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
            ';' => TokenType.Semicolon,
            else => TokenType.Statement
        };
    }

    return TokenType.Statement;
}

fn isTokenAllowed(token: TokenType, next_token: TokenType, inside_module: bool, inside_instance: bool) (errors.ParserError)!bool {
    // FIXME: Support square brackets
    return switch (token) {
        TokenType.Keyword => {
            return (!inside_module and next_token == TokenType.Statement) or // Expect statement after a keyword outside a module (eg. @MODULE >>modulename<< ...)
                    (inside_module and next_token == TokenType.Separator); // Expect separator after a keyword in a module (eg. @IN >>:<< in_1 in_2)
        },
        TokenType.Statement => {
            if (inside_module) {
                if (!inside_instance and (
                    next_token == TokenType.Separator or
                    next_token == TokenType.CloseBracket or
                    next_token == TokenType.Semicolon
                )) return true; // Inside a module, but outside any instance, expect a separator or a closing character (eg. ADD >>:<< in_1 in_2 ...)
                if (inside_instance and (next_token == TokenType.Statement or next_token == TokenType.Separator)) return true; // Inside a module and an instance, expect another statement or a separator (eg. ADD : in_1 >>in_2<< ...)
            } else {
                return (next_token == TokenType.Statement or next_token == TokenType.OpenBracket); // Outside a module and after a statement, expect another statement or an opening bracket (eg. @MODULE test >>{<<)
            }
            return errors.ParserError.UnexpectedCharacter; // Unreachable, in theory...
        },
        TokenType.Separator => {
            return next_token == TokenType.Statement; // Expecting a statement after a separator (eg. ADD : >>in_1<< in_2 ...)
        },
        TokenType.OpenBracket => {
            return (next_token == TokenType.Statement or next_token == TokenType.Keyword); // Expect a statement or a keyword after an opening bracket, just for inlining purposes (eg. @MODULE test { >>@IN<< ...})
        },
        TokenType.CloseBracket => {
            return next_token == TokenType.Keyword; // Just in case someone defines a module in the same line (eg. } >>@MODULE<< anothermodule ...)
        },
        TokenType.Semicolon => {
            return (inside_module and !inside_instance and next_token == TokenType.Statement);
        },
        else => false,
    };
}

fn handleModule(simulator: *Simulator, module_netlist: *std.ArrayList([]const u8), alloc: std.mem.Allocator) (std.mem.Allocator.Error || errors.ParserError)!void {
    var inside = false;
    var finished = false;
    var module_type: ?module.ModuleType = null;

    var type_lower = std.ArrayList(u8).init(alloc);
    for (module_netlist.items[0]) |char| {
        try type_lower.append(std.ascii.toLower(char));
    }
    defer type_lower.deinit();

    if (std.mem.eql(u8, type_lower.items, "@module")) {
        module_type = module.ModuleType.Sub;
    } else if (std.mem.eql(u8, type_lower.items, "@comb")) {
        module_type = module.ModuleType.SubCombinational;
    } else if (std.mem.eql(u8, type_lower.items, "@top")) {
        module_type = module.ModuleType.Top;
    } else {
        return errors.ParserError.InvalidModuleType;
    }

    inside = true;

    _ = module_netlist.orderedRemove(0); // Remove the module type from the netlist

    var name: std.ArrayList(u8) = std.ArrayList(u8).init(alloc); 
    defer name.deinit();
    
    while (!std.mem.eql(u8, module_netlist.items[0], "{")) {
        try name.appendSlice(module_netlist.orderedRemove(0));
    }

    _ = module_netlist.orderedRemove(0);

    var created_module: module.Module = try module.Module.init(alloc, module_type.?, name.items);

    while (!finished) {
        if (std.mem.eql(u8, module_netlist.items[0], "}")) {
            finished = true;
            break;
        }

        const name_pascal = try stringutils.pascal(module_netlist.orderedRemove(0), alloc);
        defer alloc.free(name_pascal);

        const directive_instance = std.mem.startsWith(u8, name_pascal, "@");

        const instance_type: ?gate.GateType = inline for (@typeInfo(gate.GateType).Enum.fields) |g_type| {
                if (std.mem.eql(u8, name_pascal, g_type.name)) break @enumFromInt(g_type.value);
            } else null;

        _ = module_netlist.orderedRemove(0); // remove the first separator (eg. AND >>:<< in_1 in_2 -> out_1)

        var inputs: std.ArrayList(std.ArrayList(u8)) = std.ArrayList(std.ArrayList(u8)).init(alloc);
        defer stringutils.deinitArrOfStrings(inputs);

        while (!std.mem.eql(u8, module_netlist.items[0], "->") and !std.mem.endsWith(u8, module_netlist.items[0], ";")) {
            var input_list = std.ArrayList(u8).init(alloc);
            for (module_netlist.orderedRemove(0)) |char| {
                try input_list.append(char);
            }
            try inputs.append(input_list);
        }

        _ = module_netlist.orderedRemove(0); // remove the second separator (->)

        var outputs: std.ArrayList(std.ArrayList(u8)) = std.ArrayList(std.ArrayList(u8)).init(alloc);
        defer stringutils.deinitArrOfStrings(outputs);

        if (module_netlist.items.len > 0) {
            while (!std.mem.endsWith(u8, module_netlist.items[0], ";")) {
                var output_list = std.ArrayList(u8).init(alloc);
                for (module_netlist.orderedRemove(0)) |char| {
                    try output_list.append(char);
                }
                try outputs.append(output_list);
            }
            var last_output_list = std.ArrayList(u8).init(alloc);
            for (module_netlist.orderedRemove(0)) |char| {
                if (char != ';')
                try last_output_list.append(char);
            }
            try outputs.append(last_output_list);
        }

        var inputs_slices = std.ArrayList([]const u8).init(alloc);
        defer inputs_slices.deinit();

        for (inputs.items) |input| {
            try inputs_slices.append(input.items);
        }

        var outputs_slices = std.ArrayList([]const u8).init(alloc);
        defer outputs_slices.deinit();

        for (outputs.items) |output| {
            try outputs_slices.append(output.items);
        }

        if (!directive_instance and instance_type != null) {
            try created_module.add_gate(alloc, instance_type.?, inputs_slices.items, outputs_slices.items);
        } else {
            const directive_name = try stringutils.pascal(name_pascal[1..name_pascal.len], alloc);
            defer alloc.free(directive_name);
            const directive_type: directive.DirectiveType = inline for (@typeInfo(directive.DirectiveType).Enum.fields) |d_type| {
                if (std.mem.eql(u8, directive_name, d_type.name)) break @enumFromInt(d_type.value);
            } else return errors.ParserError.InvalidGateType;
            try directive.Directive.init(directive_type, simulator, &created_module, inputs_slices.items, if (outputs_slices.items.len == 0) null else outputs_slices.items, alloc);
        }
    }

    try simulator.add_module(created_module);
}
