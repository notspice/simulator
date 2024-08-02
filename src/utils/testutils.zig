const std = @import("std");
const Simulator = @import("../simulator.zig").Simulator;

pub fn testTitle(comptime str: []const u8) void {
    const length = str.len + 2;

    std.debug.print("\n\n{str}\n", .{"=" ** length});
    std.debug.print(" {str}\n", .{str});
    std.debug.print("{str}\n\n", .{"=" ** length});
}

pub fn printAllNodeStates(simulator: *Simulator) void {
    for(simulator.*.nodes.keys()) |key| {
        std.debug.print("{s}: {d} ", .{key, @intFromBool(simulator.*.nodes.get(key).?.state)});
    }
    std.debug.print("\n\n", .{});
}
