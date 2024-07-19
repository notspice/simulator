const std = @import("std");

const api = @import("simulator/api.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const c_string: [*:0]const u8 = "hello";
    var simulator = try api.Simulator.init(c_string, alloc);

    simulator.deinit();
}