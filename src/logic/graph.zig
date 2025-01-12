const std = @import("std");

const errors = @import("../utils/errors.zig");

const gate = @import("gate.zig");
const node = @import("node.zig");

const stringutils = @import("../utils/stringutils.zig");

pub const Graph = struct {
    const Self = @This();

    nodes: std.StringArrayHashMap(node.Node),
    gates: std.StringArrayHashMap(gate.Gate),

    /// Initializes the netlist struct
    pub fn init(alloc: std.mem.Allocator) std.mem.Allocator.Error!Self {
        return Self {
            .nodes = std.StringArrayHashMap(node.Node).init(alloc),
            .gates = std.StringArrayHashMap(gate.Gate).init(alloc),
        };
    }

    /// Deinitializes the netlist struct and all its contents
    pub fn deinit(self: *Self) void {
        for (self.nodes.values()) |*curr_node| {
            curr_node.deinit();
        }

        for (self.gates.values()) |*curr_gate| {
            curr_gate.deinit();
        }

        self.nodes.deinit();
        self.gates.deinit();
    }

    /// Adds a node to the netlist if it doesn't exist yet
    pub fn addNode(self: *Self, name: []const u8, alloc: std.mem.Allocator) std.mem.Allocator.Error!void {
        if(!self.nodes.contains(name)) {
            try self.nodes.put(name, node.Node.init(alloc));
        } else {
            return;
        }
    }

    /// Adds a gate to the netlist and connects all neccessary nodes
    pub fn addGate(self: *Self, gate_type: gate.GateType, name: []const u8, input_node_names: []const []const u8, output_node_names: []const []const u8, alloc: std.mem.Allocator) (std.mem.Allocator.Error || errors.GateInitError)!void {
        if(!self.gates.contains(name)) {
            var gate_inputs = std.ArrayList(node.NodeIndex).init(alloc);
            defer gate_inputs.deinit();

            for (input_node_names) |input_node_name| {
                try self.addNode(input_node_name, alloc);
                if (self.nodes.getIndex(input_node_name)) |node_index| {
                    try gate_inputs.append(node_index);
                } else {
                    return errors.ParserError.NodeNotFound; // Unreachable in theory
                }
            }

            const new_gate = try gate.Gate.init(gate_type, gate_inputs.items, alloc);
            try self.gates.put(name, new_gate);

            for (output_node_names) |output_node_name| {
                try self.addNode(output_node_name, alloc);
                if (self.nodes.getPtr(output_node_name)) |driven_node| {
                    try driven_node.addDriver(self.gates.getIndex(name) orelse return errors.GateInitError.NodeNotFound);
                }
            }
        } else {
            return;
        }
    }

    pub fn updateAll(self: *Self) errors.SimulationError!void {
        for (self.nodes.values()) |*node_to_update| {
            try node_to_update.update(.WireOr, &self.gates, &self.nodes);
        }
    }

    pub fn advanceAll(self: *Self) void {
        for (self.nodes.values()) |*node_to_advance| {
            node_to_advance.advance();
        }
    }

    pub fn containsNode(self: *Self, node_name: []const u8) bool {
        return self.nodes.contains(node_name);
    }

    pub fn getNodeStatus(self: *Self, node_name: []const u8) bool {
        return self.nodes.get(node_name).?.state;
    }

    pub fn setNodeStatus(self: *Self, node_name: []const u8, state: bool) void {
        self.nodes.getPtr(node_name).?.set_state(state);
    }
};
