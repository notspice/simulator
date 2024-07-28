const std = @import("std");

pub fn testTitle(comptime str: []const u8) void {
    const length = str.len + 2;

    std.debug.print("\n\n{str}\n", .{"=" ** length});
    std.debug.print(" {str}\n", .{str});
    std.debug.print("{str}\n\n", .{"=" ** length});
}
