const std = @import("std");
const Simulator = @import("../../simulator.zig").Simulator;
const Module = @import("../../logic/module.zig").Module;

pub fn init(simulator: *Simulator, module: *Module, inputs: [][]const u8, alloc: std.mem.Allocator) (std.mem.Allocator.Error)!void {
    _ = simulator;
    for (inputs) |input| {
        try module.add_node(alloc, input);
    }
}