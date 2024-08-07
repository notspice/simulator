const std = @import("std");

const errors = @import("../utils/errors.zig");
const simulator = @import("../simulator.zig");
const gate = @import("gate.zig");

const Node = @import("node.zig").Node;

pub const ModuleType = enum {
    Top,
    Sub,
    SubCombinational,
};

pub const Module = struct {
    name: []const u8,
    module_type: ModuleType,
    nodes: std.StringArrayHashMap(Node),
    gates: std.ArrayList(gate.Gate),

    pub fn init(alloc: std.mem.Allocator, module_type: ModuleType, name: []const u8) Module {
        return Module {
            .name = name,
            .module_type = module_type,
            .nodes = std.StringArrayHashMap(Node).init(alloc),
            .gates = std.ArrayList(gate.Gate).init(alloc)
        };
    }

    pub fn add_node(self: *Module, alloc: std.mem.Allocator, name: []const u8) std.mem.Allocator.Error!void {
        if (!self.nodes.contains(name)) {
            try self.nodes.put(name, Node.init(alloc));
        }
    }

    // Adds a gate to the module and connects all neccessary nodes
    pub fn add_gate(self: *Module, alloc: std.mem.Allocator, gate_type: gate.GateType, inputs: std.ArrayList([]const u8), outputs: std.ArrayList([]const u8)) (std.mem.Allocator.Error || errors.ParserError)!void {
        var gate_inputs = std.ArrayList(simulator.NodeIndex).init(alloc);
        defer gate_inputs.deinit();

        for (inputs.items) |input| {
            try add_node(self, alloc, input);
            if (self.nodes.getIndex(input)) |node_index| {
                try gate_inputs.append(node_index);
            } else {
                return errors.ParserError.NodeNotFound; // Unreachable in theory
            }
        }

        const created_gate = try gate.Gate.init(gate_type, gate_inputs);
        try self.gates.append(created_gate);

        for (outputs.items) |output| {
            try add_node(self, alloc, output);
            if (self.nodes.getPtr(output)) |captured_node| {
                try captured_node.add_driver(self.gates.items.len - 1);
            }
        }

        // std.debug.print("Adding {s} with inputs {any} and outputs {any}", .{@tagName(gate_type), inputs, outputs});
    }

    pub fn tick(self: *Module) errors.SimulationError!void {
        for (self.nodes.keys()) |key| {
            try self.nodes.getPtr(key).?.*.update(.WireOr, &self.gates, &self.nodes);
        }
    }
};