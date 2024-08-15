const std = @import("std");

const errors = @import("utils/errors.zig");
const node = @import("logic/node.zig");
const gate = @import("logic/gate.zig");
const utils = @import("utils/stringutils.zig");
const parser = @import("netlist/parser.zig");
const module = @import("logic/module.zig");

const expect = std.testing.expect;
const expectError = std.testing.expectError;

pub const NodeIndex   = usize;
pub const GateIndex   = usize;
pub const InputIndex  = usize;
pub const OutputIndex = usize;

const LineType = enum {
    Node,
    Declaration
};

/// Structure representing the entire state of the Simulator
pub const Simulator = struct {
    /// Alias for the type of this struct
    const Self = @This();

    /// Circuit name obtained from the first line of the netlist file
    circuit_name: []const u8,
    modules: std.ArrayList(module.Module),

    /// Initializes the Simulator object. Allocates memory for the Nodes' and Gates' lists and builds the internal netlist based on the provided text representation
    pub fn init(text_netlist: []const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!Self {
        var simulator: Self = .{
            .circuit_name = &.{},
            .modules = std.ArrayList(module.Module).init(alloc)
        };

        try parser.parseNetlist(&simulator, text_netlist, alloc);

        return simulator;
    }

    /// Deinitializes the Simulator, freeing its memory
    pub fn deinit(self: *Simulator) void {
        for (self.modules.items) |*item| {
            item.deinit();
        }
        self.modules.deinit();
    }

    /// Resets the Nodes to their initial state
    pub fn reset(self: *Self) void {
        _ = self;

        // --TODO--
    }

    /// Calculates the new states of all Nodes, advancing the simulation by one step
    pub fn tick(self: *Self) errors.SimulationError!void {
        for (self.modules.items) |*executed_module| {
            try executed_module.update_all();
        }
        for (self.modules.items) |*executed_module| {
            executed_module.advance_all();
        }
    }

    /// Probes for the state of a particular node
    pub fn getNodeState(self: Self, node_index: u32) bool {
        _ = self;
        _ = node_index;

        // --TODO--
    }

    /// Probes for the state of a particular node
    pub fn getNodeStateString(self: Self, node_name: []const u8) bool {
        for (self.modules.items) |*searched_module| {
            if (searched_module.containsNode(node_name)) return searched_module.getNodeStatus(node_name);
        }
        return false;
    }

    pub fn setNodeStateString(self: Self, node_name: []const u8, state: bool) void {
        for (self.modules.items) |*searched_module| {
            if (searched_module.containsNode(node_name)) return searched_module.setNodeStatus(node_name, state);
        }
    }

    pub fn add_module(self: *Self, module_to_add: module.Module) std.mem.Allocator.Error!void {
        try self.modules.append(module_to_add);
    }
};