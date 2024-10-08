const std = @import("std");

const errors = @import("../utils/errors.zig");
const simulator = @import("../simulator.zig");
const gate = @import("gate.zig");

const Node = @import("node.zig").Node;

const stringutils = @import("../utils/stringutils.zig");

pub const ModuleType = enum {
    Top,
    Sub,
    SubCombinational,
};

pub const Module = struct {
    name: std.ArrayList(u8),
    module_type: ModuleType,
    nodes: std.StringArrayHashMap(Node),
    inputs: std.BufSet,
    node_names: std.ArrayList(std.ArrayList(u8)),
    gates: std.ArrayList(gate.Gate),

    pub fn init(alloc: std.mem.Allocator, module_type: ModuleType, name: []const u8) std.mem.Allocator.Error!Module {
        var name_owned = std.ArrayList(u8).init(alloc);
        try name_owned.appendSlice(name);

        return Module {
            .name = name_owned,
            .module_type = module_type,
            .nodes = std.StringArrayHashMap(Node).init(alloc),
            .node_names = std.ArrayList(std.ArrayList(u8)).init(alloc),
            .gates = std.ArrayList(gate.Gate).init(alloc),
            .inputs = std.BufSet.init(alloc),
        };
    }

    pub fn deinit(self: *Module) void {
        for (self.nodes.values()) |*curr_node| {
            curr_node.deinit();
        }

        for (self.gates.items) |*curr_gate| {
            curr_gate.deinit();
        }

        stringutils.deinitArrOfStrings(self.node_names);

        self.nodes.deinit();
        self.gates.deinit();
        self.name.deinit();
        self.inputs.deinit();
    }

    pub fn add_node(self: *Module, alloc: std.mem.Allocator, name: []const u8) std.mem.Allocator.Error!void {
        if (!self.nodes.contains(name)) {
            var node_name_owned = std.ArrayList(u8).init(alloc);
            try node_name_owned.appendSlice(name);

            try self.node_names.append(node_name_owned);
            const node_name_index = self.node_names.items.len - 1;
            const node_name_slice = self.node_names.items[node_name_index].items;

            try self.nodes.put(node_name_slice, Node.init(alloc));
        }
    }

    pub fn add_input(self: *Module, alloc: std.mem.Allocator, name: []const u8) std.mem.Allocator.Error!void {
        if (!self.nodes.contains(name)) {
            var node_name_owned = std.ArrayList(u8).init(alloc);
            try node_name_owned.appendSlice(name);

            try self.node_names.append(node_name_owned);
            const node_name_index = self.node_names.items.len - 1;
            const node_name_slice = self.node_names.items[node_name_index].items;

            try self.nodes.put(node_name_slice, Node.init(alloc));
            try self.inputs.insert(node_name_slice);
        }
    }

    // Adds a gate to the module and connects all neccessary nodes
    pub fn add_gate(self: *Module, alloc: std.mem.Allocator, gate_type: gate.GateType, name: []const u8, inputs: [][]const u8, outputs: [][]const u8) (std.mem.Allocator.Error || errors.ParserError)!void {
        var gate_inputs = std.ArrayList(simulator.NodeIndex).init(alloc);
        defer gate_inputs.deinit();

        // TODO: Do something with the name...
        std.debug.print("Adding named gate: {s}\n", .{name});

        for (inputs) |input| {
            try self.add_node(alloc, input);
            if (self.nodes.getIndex(input)) |node_index| {
                try gate_inputs.append(node_index);
            } else {
                return errors.ParserError.NodeNotFound; // Unreachable in theory
            }
        }

        const created_gate = try gate.Gate.init(gate_type, gate_inputs.items, alloc);
        try self.gates.append(created_gate);

        for (outputs) |output| {
            try self.add_node(alloc, output);
            if (self.nodes.getPtr(output)) |captured_node| {
                try captured_node.add_driver(self.gates.items.len - 1);
            }
        }
    }

    pub fn update_all(self: *Module) errors.SimulationError!void {
        for (self.nodes.keys()) |key| {
            if (!self.inputs.contains(key)) {
                try self.nodes.getPtr(key).?.update(.WireOr, &self.gates, &self.nodes);
            }
        }
    }

    pub fn advance_all(self: *Module) void {
        for (self.nodes.keys()) |key| {
            if (!self.inputs.contains(key)) {
                self.nodes.getPtr(key).?.advance();
            }
        }
    }

    pub fn containsNode(self: *Module, node_name: []const u8) bool {
        return self.nodes.contains(node_name);
    }

    pub fn getNodeStatus(self: *Module, node_name: []const u8) bool {
        return self.nodes.get(node_name).?.state;
    }

    pub fn setNodeStatus(self: *Module, node_name: []const u8, state: bool) void {
        self.nodes.getPtr(node_name).?.set_state(state);
    }
};
