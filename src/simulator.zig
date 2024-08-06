const std = @import("std");

const errors = @import("utils/errors.zig");
const node = @import("logic/node.zig");
const gate = @import("logic/gate.zig");
const utils = @import("utils/stringutils.zig");
const parser = @import("netlist/parser.zig");

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
    /// List of Nodes in the circuit. Owns the memory that stores the Nodes.
    nodes: std.StringArrayHashMap(node.Node),
    /// List of Gates in the circuit. Owns the memory that stores the Gates.
    gates: std.ArrayList(gate.Gate),

    /// Initializes the Simulator object. Allocates memory for the Nodes' and Gates' lists and builds the internal netlist based on the provided text representation
    pub fn init(text_netlist: [*:0]const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!Self {
        var simulator: Self = .{
            .circuit_name = &.{},
            .nodes = std.StringArrayHashMap(node.Node).init(alloc),
            .gates = std.ArrayList(gate.Gate).init(alloc)
        };

        try parser.parseNetlist(&simulator, text_netlist, alloc);

        return simulator;
    }

    /// Deinitializes the Simulator, freeing its memory
    pub fn deinit(self: *Simulator) void {
        for (self.nodes.keys()) |key| {
            self.nodes.getPtr(key).?.*.deinit();
        }
        self.nodes.deinit();

        for (self.gates.items) |processed_gate| {
            processed_gate.deinit();
        }
        self.gates.deinit();
    }

    /// Resets the Nodes to their initial state
    pub fn reset(self: *Self) void {
        _ = self;

        // --TODO--
    }

    /// Calculates the new states of all Nodes, advancing the simulation by one step
    pub fn tick(self: *Self) errors.SimulationError!void {
        for (self.nodes.keys()) |key| {
            try self.nodes.getPtr(key).?.*.update(.WireOr, &self.gates, &self.nodes);
        }
    }

    /// Probes for the state of a particular node
    pub fn getNodeState(self: Self, node_index: u32) bool {
        _ = self;
        _ = node_index;

        // --TODO--
    }
};
