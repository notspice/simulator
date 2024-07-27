const std = @import("std");

const api = @import("api.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const text_netlist: [*:0]const u8 =
        \\NOR N1 N2
        \\AND N2 N3
        \\XOR N5 N6
    ;

    var simulator = try api.Simulator.init(text_netlist, alloc);
    defer simulator.deinit();
}
