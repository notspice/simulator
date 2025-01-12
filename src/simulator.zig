const std = @import("std");

const errors = @import("utils/errors.zig");
const node = @import("logic/node.zig");
const gate = @import("logic/gate.zig");
const utils = @import("utils/stringutils.zig");
const parser = @import("netlist/parser.zig");
const graph = @import("logic/graph.zig");

const expect = std.testing.expect;
const expectError = std.testing.expectError;

const LineType = enum {
    Node,
    Declaration
};

/// Structure representing the entire state of the Simulator
pub const Simulator = struct {
    /// Alias for the type of this struct
    const Self = @This();

    /// Circuit name obtained from the first line of the netlist file
    circuit_name: std.ArrayList(u8),
    /// Graph of gates and nodes in the circuit
    graph: graph.Graph,

    /// Initializes the Simulator object. Allocates memory for the Nodes' and Gates' lists and builds the internal netlist based on the provided text representation
    pub fn init(text_netlist: []const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!Self {
        var simulator: Self = .{
            .circuit_name = std.ArrayList(u8).init(alloc),
            .graph = try graph.Graph.init(alloc)
        };

        try parser.parseNetlist(&simulator, text_netlist, alloc);

        return simulator;
    }

    /// Deinitializes the Simulator, freeing its memory
    pub fn deinit(self: *Simulator) void {
        self.circuit_name.deinit();
        self.graph.deinit();
    }

    /// Resets the Nodes to their initial state
    pub fn reset(self: *Self) void {
        _ = self;

        // --TODO--
    }

    /// Calculates the new states of all Nodes, advancing the simulation by one step
    pub fn tick(self: *Self) errors.SimulationError!void {
        try self.graph.updateAll();
        self.graph.advanceAll();
    }

    /// Probes for the state of a particular node
    pub fn getNodeState(self: Self, node_name: []const u8) bool {
        return if (self.graph.nodes.get(node_name)) |found_node| found_node.getState() else false;
    }

    pub fn setNodeState(self: Self, node_name: []const u8, state: bool) void {
        if (self.graph.nodes.getPtr(node_name)) |found_node| found_node.setState(state);
    }
};