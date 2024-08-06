const std = @import("std");

const Simulator = @import("../simulator.zig").Simulator;
const NodeIndex = @import("../simulator.zig").NodeIndex;
const errors = @import("../utils/errors.zig");
const stringutils = @import("../utils/stringutils.zig");
const gate = @import("../logic/gate.zig");
const node = @import("../logic/node.zig");

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
pub fn parseNetlist(_: *Simulator, text_netlist: [*:0]const u8, _: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!void {
    // Convert 0-terminated string to a Zig slice.
    const text_netlist_length = std.mem.len(text_netlist);
    const text_netlist_slice = text_netlist[0..text_netlist_length];

    // Separate the input text into lines.
    var lines = std.mem.tokenizeAny(u8, text_netlist_slice, "\n");
    var line_num: usize = 0;

    var inside_module: bool = false;
    var inside_instance: bool = false;
    // Iterate over the lines and tokenize all words
    while (lines.next()) |line| : (line_num += 1) {
        var words = std.mem.tokenizeAny(u8, line, " ");
        
        var index: usize = 0;
        while (words.next()) |word| : (index += 1) {
            const token = try categorize(word, line_num);

            if (token == TokenType.OpenBracket) inside_module = true;
            if (token == TokenType.CloseBracket) inside_module = false;

            if (inside_module and !inside_instance and token == TokenType.Separator) inside_instance = true // Enter instance
            else if (inside_instance and token == TokenType.Separator) inside_instance = false; // Instance end

            if (words.peek()) |next_word| {
                std.debug.print("w: {s} nw: {s} t: {s} im: {?} ii: {?}\n", .{ word, next_word, @tagName(token), inside_module, inside_instance});
                if (try isTokenAllowed(token, try categorize(next_word, line_num), inside_module, inside_instance)) continue
                else return errors.ParserError.UnexpectedCharacter;
            }
        }
    }
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

fn isTokenAllowed(token: TokenType, next_token: TokenType, inside_module: bool, inside_instance: bool) (errors.ParserError)!bool {
    // FIXME: Support square brackets
    return switch (token) {
        TokenType.Keyword => {
            return (!inside_module and next_token == TokenType.Statement) or // Expect statement after a keyword outside a module (eg. @MODULE >>modulename<< ...)
                    (inside_module and next_token == TokenType.Separator); // Expect separator after a keyword in a module (eg. @IN >>:<< in_1 in_2)
        },
        TokenType.Statement => {
            if (inside_module) {
                if (!inside_instance and next_token == TokenType.Separator) return true;
                if (inside_instance and (next_token == TokenType.Statement or next_token == TokenType.Separator)) return true;
            } else {
                return (next_token == TokenType.Statement or next_token == TokenType.OpenBracket);
            }
            return errors.ParserError.UnexpectedCharacter;
        },
        TokenType.Separator => {
            return next_token == TokenType.Statement;
        },
        TokenType.OpenBracket => {
            return (next_token == TokenType.Statement or next_token == TokenType.Keyword);
        },
        TokenType.CloseBracket => {
            return next_token == TokenType.Keyword; // Just in case someone defines a module in the same line (eg. } @MODULE anothermodule ...)
        },
        else => false,
    };
}
