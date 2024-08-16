const std = @import("std");
const Simulator = @import("../simulator.zig").Simulator;
const Module = @import("../logic/module.zig").Module;

const in = @import("./directives/in.zig");

pub const DirectiveType = enum {
    In,
    Out,
    Probe,
    Breakpoint,
};

pub const Directive = union(DirectiveType) {
    pub fn init(directive_type: DirectiveType, simulator: *Simulator, module: *Module, inputs: [][]const u8, outputs: ?[][]const u8, alloc: std.mem.Allocator) (std.mem.Allocator.Error)!void {
        switch (directive_type) {
            .In => try in.init(simulator, module, inputs, alloc),
            .Out => { _ = outputs; },
            else => {},
        }
    }
};