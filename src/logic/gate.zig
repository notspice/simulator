const std = @import("std");

const node = @import("node.zig");
const errors = @import("../utils/errors.zig");

const expect = std.testing.expect;
const expectError = std.testing.expectError;

pub const GateType = enum {
    // Two-input gates
    And,
    Or,
    Xor,
    Nand,
    Nor,
    Xnor,

    // One-input gates
    Not,
    Buf,

    // Ports
    Input,
};

/// Representation of a gate, with its type and input nodes
pub const Gate = union(GateType) {
    /// Alias for the type of this struct
    const Self = @This();
    /// Alias for the list of inputs
    const InputList = std.ArrayList(node.NodeIndex);

    // Two-input gates and their inputs
    And: std.ArrayList(node.NodeIndex),
    Or: std.ArrayList(node.NodeIndex),
    Xor: std.ArrayList(node.NodeIndex),
    Nand: std.ArrayList(node.NodeIndex),
    Nor: std.ArrayList(node.NodeIndex),
    Xnor: std.ArrayList(node.NodeIndex),

    // One-input gates
    Not: std.ArrayList(node.NodeIndex),
    Buf: std.ArrayList(node.NodeIndex),

    // Input device, which also holds a reference to an externally controlled bool that indicates whether it's enabled
    Input: node.PortIndex,

    /// Initializes the Gate object. Accepts an externally allocated list of pointers to Node, takes responsibility for deallocating. Must be deinitialized using .deinit()
    pub fn init(gate_type: GateType, input_nodes: std.ArrayList(node.NodeIndex), external_state: ?node.PortIndex) errors.GateInitError!Self {
        // Check if the number of inputs is correct for the given gate type
        const input_nodes_count = input_nodes.items.len;
        const input_nodes_count_valid = switch (gate_type) {
            .And => input_nodes_count >= 2,
            .Or => input_nodes_count >= 2,
            .Xor => input_nodes_count >= 2,
            .Nand => input_nodes_count >= 2,
            .Nor => input_nodes_count >= 2,
            .Xnor => input_nodes_count >= 2,

            .Not => input_nodes_count == 1,
            .Buf => input_nodes_count == 1,

            .Input => input_nodes_count == 0,
        };
        if (!input_nodes_count_valid) {
            input_nodes.deinit();
            return errors.GateInitError.WrongNumberOfInputs;
        }

        // Check if the external state reference for Inputs is provided as required
        // TODO: Remove
        if (gate_type == .Input and external_state == null) {
            input_nodes.deinit();
            return errors.GateInitError.MissingExternalState;
        } else if (gate_type != .Input and external_state != null) {
            input_nodes.deinit();
            return errors.GateInitError.UnnecessaryExternalState;
        }

        // Immediately deallocate input_nodes if the Gate is an Input
        // TODO: Remove
        if (gate_type == .Input) {
            input_nodes.deinit();
        }

        return switch (gate_type) {
            .And => Self{ .And = input_nodes },
            .Or => Self{ .Or = input_nodes },
            .Xor => Self{ .Xor = input_nodes },
            .Nand => Self{ .Nand = input_nodes },
            .Nor => Self{ .Nor = input_nodes },
            .Xnor => Self{ .Xnor = input_nodes },

            .Not => Self{ .Not = input_nodes },
            .Buf => Self{ .Buf = input_nodes },

            .Input => Self{ .Input = external_state orelse return errors.GateInitError.MissingExternalState },
        };
    }

    /// Deinitializes the Gate object, freeing its memory
    pub fn deinit(self: Gate) void {
        switch (self) {
            .And, .Or, .Xor, .Nand, .Nor, .Xnor, .Not, .Buf => |*inputs| inputs.deinit(),

            else => {},
        }
    }

    /// Returns the gate's output based on the input Nodes' states and the Gate's logic function
    pub fn output(self: Self, nodes: *std.StringArrayHashMap(node.Node), ports: *std.ArrayList(bool)) errors.SimulationError!bool {
        switch (self) {
            // Two-input gates
            .And => |inputs| {
                var result = true;
                for (inputs.items) |input_index| {
                    const processed_node = nodes.*.values()[input_index];
                    result = result and processed_node.state;
                }
                return result;
            },
            .Or => |inputs| {
                var result = false;
                for (inputs.items) |input_index| {
                    const processed_node = nodes.*.values()[input_index];
                    result = result or processed_node.state;
                }
                return result;
            },
            .Xor => |inputs| {
                var result = false;
                for (inputs.items) |input_index| {
                    const processed_node = nodes.*.values()[input_index];
                    if (processed_node.state) result = !result;
                }
                return result;
            },
            .Nand => |inputs| {
                var result = true;
                for (inputs.items) |input_index| {
                    const processed_node = nodes.*.values()[input_index];
                    result = result and processed_node.state;
                }
                return !result;
            },
            .Nor => |inputs| {
                var result = false;
                for (inputs.items) |input_index| {
                    const processed_node = nodes.*.values()[input_index];
                    result = result or processed_node.state;
                }
                return !result;
            },
            .Xnor => |inputs| {
                var result = false;
                for (inputs.items) |input_index| {
                    const processed_node = nodes.*.values()[input_index];
                    if (processed_node.state) result = !result;
                }
                return !result;
            },

            // One-input gates
            .Not => |_| {
                const processed_node = nodes.*.values()[0];
                return !processed_node.state;
            },
            .Buf => |_| {
                const processed_node = nodes.*.values()[0];
                return processed_node.state;
            },

            // Input device
            // TODO: Remove
            .Input => |port_index| {
                const port_state = ports.items[port_index];
                return port_state;
            },
        }
    }
};
