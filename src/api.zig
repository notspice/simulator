const std = @import("std");
const expect = std.testing.expect;

const errors = @import("errors.zig");

/// Logic function performed by the wire
pub const WireFunction = enum {
    /// If all drivers output 1, the wire's state is 1
    WireAnd,
    /// If at least one driver outputs 1, the wire's state is 1
    WireOr,
    /// Only one gate is allowed to drive this wire, conflicts are resolved before simulation
    WireUniqueDriver,
};

/// The logical circuit node (wire).
///
/// The Node is where the state of the circuit is remembered between ticks
pub const Node = struct {
    /// Current state of the node, referenced by connected gates' inputs
    state: bool,
    /// List of references to gates that drive this Node
    drivers: std.ArrayList(*Gate),

    /// Initialize the Node object, allocating memory for the drivers' list
    pub fn init(alloc: std.mem.Allocator) Node {
        return Node{ .state = false, .drivers = std.ArrayList(*Gate).init(alloc) };
    }

    pub fn add_driver(self: *Node, gate: *Gate) !void {
        try self.drivers.append(gate);
    }

    /// Free the memory allocated within the Node
    pub fn deinit(self: *Node) void {
        self.drivers.deinit();
    }

    /// Update the state of the Node, based on the drivers' states and the selected wire function
    pub fn update(self: *Node, wire_function: WireFunction) !void {
        self.state = switch (wire_function) {
            // Look for any driver that outputs 0 and set the state to 0 if any were found
            // If no driver outputs 0 (all output 1), set the state to 1
            .WireAnd => for (self.drivers.items) |driver| {
                if (driver.*.output() == false) break false;
            } else no_zeros: {
                break :no_zeros true;
            },

            // Look for any driver that outputs 1 and set the state to 1 if any were found
            // If no driver outputs 1 (all output 0), set the state to 0
            .WireOr => for (self.drivers.items) |driver| {
                if (driver.*.output() == true) break true;
            } else no_zeros: {
                break :no_zeros false;
            },

            // If only one driver is allowed, take the value of the only existing one (should be checked before synthesis)
            .WireUniqueDriver => if (self.drivers.getLastOrNull()) |driver| driver.*.output() else false,
        };
    }
};

pub const GateType = enum {
    // Two-input gates
    And, Or, Xor, Nand, Nor, Xnor,

    // One-input gates
    Not, Buf,

    // Ports
    Input
};

/// Representation of a gate, with its type and input nodes
pub const Gate = union(GateType) {
    /// Alias for the type of this struct
    const Self = @This();
    /// Alias for the list of inputs
    const InputList = std.ArrayList(*Node);

    // Two-input gates and their inputs
    And  : InputList,
    Or   : InputList,
    Xor  : InputList,
    Nand : InputList,
    Nor  : InputList,
    Xnor : InputList,

    // One-input gates
    Not : InputList,
    Buf : InputList,

    // Input device, which also holds a reference to an externally controlled bool that indicates whether it's enabled
    Input : *bool,

    /// Initializes the gate object. Takes ownership of the inputs array, must be deallocated using .deinit()
    pub fn init(comptime gate_type: GateType, input_nodes: anytype, external_state: anytype, alloc: std.mem.Allocator) !Self {
        const input_nodes_type_info = @typeInfo(@TypeOf(input_nodes));
        if(input_nodes_type_info != .Struct) {
            @compileError("Expected tuple or struct, found " ++ @typeName(@TypeOf(input_nodes)));
        }
        const input_nodes_count = input_nodes_type_info.Struct.fields.len;
        const input_nodes_count_valid = switch(gate_type) {
            .And    => input_nodes_count >= 2,
            .Or     => input_nodes_count >= 2,
            .Xor    => input_nodes_count >= 2,
            .Nand   => input_nodes_count >= 2,
            .Nor    => input_nodes_count >= 2,
            .Xnor   => input_nodes_count >= 2,

            .Not    => input_nodes_count == 1,
            .Buf    => input_nodes_count == 1,

            .Input  => input_nodes_count == 0
        };
        if(!input_nodes_count_valid) {
            @compileError("Invalid number of inputs for " ++ @tagName(gate_type) ++ " gate");
        }

        const external_state_type_info = @typeInfo(@TypeOf(external_state));
        if(external_state_type_info != .Struct) {
            @compileError("Expected tuple or struct, found " ++ @typeName(@TypeOf(external_state)));
        }

        if(gate_type == .Input) {
            const external_state_count = external_state_type_info.Struct.fields.len;
            if(external_state_count != 1) {
                @compileError("Expected exactly 1 external state reference");
            }

            const external_state_field = external_state_type_info.Struct.fields[0];
            const external_state_field_type = external_state_field.type;
            if(external_state_field_type != *bool) {
                @compileError("Expected field of type *bool, found " ++ @typeName(external_state_field_type));
            }
        }

        var input_nodes_array = std.ArrayList(*Node).init(alloc);
        inline for(input_nodes) |input| {
            try input_nodes_array.append(input);
        }
        
        return switch(gate_type) {
            .And  => Self { .And  = input_nodes_array },
            .Or   => Self { .Or   = input_nodes_array },
            .Xor  => Self { .Xor  = input_nodes_array },
            .Nand => Self { .Nand = input_nodes_array },
            .Nor  => Self { .Nor  = input_nodes_array },
            .Xnor => Self { .Xnor = input_nodes_array },

            .Not  => Self { .Not = input_nodes_array },
            .Buf  => Self { .Buf = input_nodes_array },

            .Input => Self { .Input = external_state[0] }
        };
    }

    pub fn deinit(self: Gate) void {
        switch(self) {
            .And, .Or, .Xor, .Nand, .Nor, .Xnor, .Not, .Buf => |*inputs| inputs.deinit(),

            else => {}
        }
    }

    /// Get the gate's output based on the input Nodes' states and the gate's logic function
    pub fn output(self: Self) bool {
        switch(self) {
            // Two-input gates
            .And => |inputs| {
                var result = true;
                for (inputs.items) |input| {
                    result = result and input.*.state;
                }
                return result;
            },
            .Or => |inputs| {
                var result = false;
                for (inputs.items) |input| {
                    result = result or input.*.state;
                }
                return result;
            },
            .Xor => |inputs| {
                var result = false;
                for (inputs.items) |input| {
                    if (input.*.state) result = !result;
                }
                return result;
            },
            .Nand => |inputs| {
                var result = true;
                for (inputs.items) |input| {
                    result = result and input.*.state;
                }
                return !result;
            },
            .Nor => |inputs| {
                var result = false;
                for (inputs.items) |input| {
                    result = result or input.*.state;
                }
                return !result;
            },
            .Xnor => |inputs| {
                var result = false;
                for (inputs.items) |input| {
                    if (input.*.state) result = !result;
                }
                return !result;
            },

            // One-input gates
            .Not => |inputs| {
                return !inputs.items[0].state;
            },
            .Buf => |inputs| {
                return inputs.items[0].state;
            },

            // Input device
            .Input => |external_state| {
                return external_state.*;
            }
        }
    }
};

test "two-input logic functions" {
    var node1 = Node.init(std.testing.allocator);
    defer node1.deinit();
    var node2 = Node.init(std.testing.allocator);
    defer node2.deinit();

    const input_scenarios = [4][2]bool{
        .{false, false}, 
        .{false, true}, 
        .{true, false}, 
        .{true, true}
    };

    std.debug.print("\nTwo-input logic function tests\n\n", .{});

    for(input_scenarios) |input_states| {
        var input_state1 = input_states[0];
        var input_state2 = input_states[1];

        var input1 = try Gate.init(.Input, .{}, .{&input_state1}, std.testing.allocator);
        defer input1.deinit();
        
        var input2 = try Gate.init(.Input, .{}, .{&input_state2}, std.testing.allocator);
        defer input2.deinit();

        try node1.add_driver(&input1);
        try node2.add_driver(&input2);

        try node1.update(.WireOr);
        try node2.update(.WireOr);

        var and_gate = try Gate.init(GateType.And, .{&node1, &node2}, .{}, std.testing.allocator);
        defer and_gate.deinit();

        var or_gate = try Gate.init(GateType.Or, .{&node1, &node2}, .{}, std.testing.allocator);
        defer or_gate.deinit();

        var xor_gate = try Gate.init(GateType.Xor, .{&node1, &node2}, .{}, std.testing.allocator);
        defer xor_gate.deinit();

        var nand_gate = try Gate.init(GateType.Nand, .{&node1, &node2}, .{}, std.testing.allocator);
        defer nand_gate.deinit();

        var nor_gate = try Gate.init(GateType.Nor, .{&node1, &node2}, .{}, std.testing.allocator);
        defer nor_gate.deinit();

        var xnor_gate = try Gate.init(GateType.Xnor, .{&node1, &node2}, .{}, std.testing.allocator);
        defer xnor_gate.deinit();

        var not_gate = try Gate.init(GateType.Not, .{&node1}, .{}, std.testing.allocator);
        defer not_gate.deinit();

        var buf_gate = try Gate.init(GateType.Buf, .{&node1}, .{}, std.testing.allocator);
        defer buf_gate.deinit();

        std.debug.print("Inputs: <{}, {}>\n", .{@intFromBool(input_state1), @intFromBool(input_state2)});

        std.debug.print("AND:  {d} and  {d} = {d}\n", .{@intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(and_gate.output())});
        try expect(and_gate.output()  == (input_state1 and input_state2));

        std.debug.print("OR:   {d} or   {d} = {d}\n", .{@intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(or_gate.output())});
        try expect(or_gate.output()   == (input_state1 or input_state2));

        std.debug.print("XOR:  {d} xor  {d} = {d}\n", .{@intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(xor_gate.output())});
        try expect(xor_gate.output()  == ((input_state1 and !input_state2) or (!input_state1 and input_state2)));

        std.debug.print("NAND: {d} nand {d} = {d}\n", .{@intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(nand_gate.output())});
        try expect(nand_gate.output() == !(input_state1 and input_state2));

        std.debug.print("NOR:  {d} nor  {d} = {d}\n", .{@intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(nor_gate.output())});
        try expect(nor_gate.output()  == !(input_state1 or input_state2));

        std.debug.print("XNOR: {d} xnor {d} = {d}\n", .{@intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(xnor_gate.output())});
        try expect(xnor_gate.output() == !((input_state1 and !input_state2) or (!input_state1 and input_state2)));

        std.debug.print("NOT:     not {d} = {d}\n", .{@intFromBool(input_state1), @intFromBool(not_gate.output())});
        try expect(not_gate.output() == !input_state1);

        std.debug.print("BUF:         {d} = {d}\n\n", .{@intFromBool(input_state1), @intFromBool(buf_gate.output())});
        try expect(buf_gate.output() == input_state1);
    }
}

/// Structure representing the entire state of the Simulator
pub const Simulator = struct {
    /// Map of Nodes and their IDs. Owns the memory that stores the Nodes.
    nodes: std.ArrayList(Node),
    /// List of gates within the circuit. Owns the memory that stores the Gates.
    gates: std.ArrayList(Gate),

    /// Initialize the Simulator object.
    ///
    /// Allocates memory for the Nodes' and Gates' collections and builds the internal netlist based on the provided text representation
    pub fn init(text_netlist: [*:0]const u8, alloc: std.mem.Allocator) !Simulator {
        var simulator: Simulator = .{ 
            .nodes = std.ArrayList(Node).init(alloc),
            .gates = std.ArrayList(Gate).init(alloc) 
        };

        try simulator.parse_netlist(text_netlist);

        return simulator;
    }

    /// Free the memory allocated within the Simulator
    pub fn deinit(self: *Simulator) void {
        self.nodes.deinit();
        self.gates.deinit();
    }

    /// Take the text representation of the netlist and transfor it into appropriately connected Nodes and Gates
    fn parse_netlist(self: *Simulator, text_netlist: [*:0]const u8) !void {
        _ = self;

        // Convert 0-terminated string to a Zig slice.
        const text_netlist_length = std.mem.len(text_netlist);
        const text_netlist_slice = text_netlist[0..text_netlist_length];

        // Separate the input text into lines (tokens).
        var tokens = std.mem.splitSequence(u8, text_netlist_slice, &[_]u8{'\n'});
        while (tokens.next()) |token| {
            std.debug.print("{any}\n", .{token});
        }
    }

    /// Reset the Nodes to their initial state
    pub fn reset(self: *Simulator) void {
        _ = self;

        // --TODO--
    }

    /// Calculate the new states of all Nodes, advancing the simulation by one step
    pub fn tick(self: *Simulator) void {
        _ = self;

        // --TODO--
    }

    /// Probe for the state of a particular node
    pub fn get_node_state(self: Simulator, node_index: u32) bool {
        _ = self;
        _ = node_index;

        // --TODO--
    }
};
