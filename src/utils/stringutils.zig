const std = @import("std");
const expect = std.testing.expect;

pub fn strip(str: []const u8) []const u8 {
    var i: usize = 0;
    var leading_strip_idx: usize = 0;
    loop: while(i < str.len) : (i += 1) {
        if(std.ascii.isWhitespace(str[i])) continue :loop else {
            leading_strip_idx = i;
            break :loop;
        }
    }
    i = str.len;
    var trailing_strip_idx: usize = str.len;
    loop: while(i > 0) : (i -= 1) {
        if(std.ascii.isWhitespace(str[i - 1])) continue :loop else {
            trailing_strip_idx = i;
            break :loop;
        }
    }

    return str[leading_strip_idx..trailing_strip_idx];
}

pub fn pascal(str: []const u8, alloc: std.mem.Allocator) std.mem.Allocator.Error![]u8 {
    const str_pascal = try alloc.alloc(u8, str.len);
    for(str, 0..) |char, idx| {
        str_pascal[idx] = if(idx == 0) std.ascii.toUpper(char) else std.ascii.toLower(char);
    }
    return str_pascal;
}

pub fn deinitArrOfStrings(arr: std.ArrayList(std.ArrayList(u8))) void {
    for (arr.items) |item| {
        item.deinit();
    }
    arr.deinit();
}

test "strip" {
    try expect(std.mem.eql(u8, strip("   bajo "), "bajo"));
    try expect(std.mem.eql(u8, strip("\n jajo \t"), "jajo"));
}

test "pascal" {
    const bajo_pascal = try pascal("bajo", std.testing.allocator);
    defer std.testing.allocator.free(bajo_pascal);
    const jajo_pascal = try pascal("JAjO", std.testing.allocator);
    defer std.testing.allocator.free(jajo_pascal);
    
    try expect(std.mem.eql(u8, bajo_pascal, "Bajo"));
    try expect(std.mem.eql(u8, jajo_pascal, "Jajo"));
}