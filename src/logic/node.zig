const std = @import("std");

const gate = @import("gate.zig");
const errors = @import("../utils/errors.zig");
const GateIndex = @import("../simulator.zig").GateIndex;

const expect = std.testing.expect;
const expectError = std.testing.expectError;

/// Logic function performed by the wire
pub const WireFunction = enum {
    /// If all drivers output 1, the wire's state is 1
    WireAnd,
    /// If at least one driver outputs 1, the wire's state is 1
    WireOr,
    /// Only one gate is allowed to drive this wire
    WireUniqueDriver,
};

/// The logical circuit node (wire).
///
/// The Node is where the state of the circuit is remembered between ticks
pub const Node = struct {
    /// Alias for the type of this struct
    const Self = @This();
    /// Newly computed state of the node
    new_state: bool,
    /// Current state of the node
    state: bool,
    /// List of references to gates that drive this Node
    drivers: std.ArrayList(GateIndex),

    /// Initialize the Node object, allocating memory for the drivers' list
    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{ 
            .state = false,
            .new_state = false,
            .drivers = std.ArrayList(GateIndex).init(alloc) 
        };
    }

    /// Connect the output of a gate to this Node
    pub fn add_driver(self: *Self, gate_index: GateIndex) std.mem.Allocator.Error!void {
        try self.drivers.append(gate_index);
    }

    /// Free the memory allocated within the Node
    pub fn deinit(self: *Self) void {
        self.drivers.deinit();
    }

    /// Update the state of the Node, based on the drivers' states and the selected wire function
    pub fn update(self: *Self, wire_function: WireFunction, gates: *std.ArrayList(gate.Gate), nodes: *std.StringArrayHashMap(Node)) errors.SimulationError!void {
        self.new_state = if(self.drivers.items.len == 0) self.state else switch (wire_function) {
            // Look for any driver that outputs 0 and set the state to 0 if any were found
            // If no driver outputs 0 (all output 1), set the state to 1
            .WireAnd => for (self.drivers.items) |driver_index| {
                const processed_gate = gates.items[driver_index];
                if ((try processed_gate.output(nodes)) == false) break false;
            } else no_zeros: {
                break :no_zeros true;
            },

            // Look for any driver that outputs 1 and set the state to 1 if any were found
            // If no driver outputs 1 (all output 0), set the state to 0
            .WireOr => for (self.drivers.items) |driver_index| {
                const processed_gate = gates.items[driver_index];
                if ((try processed_gate.output(nodes)) == true) break true;
            } else no_zeros: {
                break :no_zeros false;
            },

            // If only one driver is allowed, return an error in case more drivers are attached
            .WireUniqueDriver => if (self.drivers.items.len == 1) (try gates.items[0].output(nodes)) else return errors.SimulationError.TooManyNodeDrivers,
        };
    }

    /// Advance the newly computed state to the main state field
    pub fn advance(self: *Self) void {
        self.state = self.new_state;
    }
};
