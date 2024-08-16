const std = @import("std");
const Simulator = @import("../simulator.zig").Simulator;
const Module = @import("../logic/module.zig").Module;

const in = @import("./directives/in.zig");

pub const DirectiveType = enum {
    In,
    Out,
    // Probe,
    // Breakpoint,
};

pub const Directive = union(DirectiveType) {
    In: void,
    Out: void,
    
    pub fn init(directive_type: DirectiveType, simulator: *Simulator, module: *Module, inputs: [][]const u8, outputs: ?[][]const u8, alloc: std.mem.Allocator) (std.mem.Allocator.Error)!Directive {
        _ = outputs;
        switch (directive_type) {
            .In => {
                try in.init(simulator, module, inputs, alloc);
                return Directive { .In = {} };
            },
            else => {}
        }
        return std.mem.Allocator.Error.OutOfMemory;
    }
};