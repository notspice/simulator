const std = @import("std");
const expect = std.testing.expect;
const expectError = std.testing.expectError;

const errors = @import("errors.zig");

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
    /// Current state of the node, referenced by connected gates' inputs
    state: bool,
    /// List of references to gates that drive this Node
    drivers: std.ArrayList(*Gate),

    /// Initialize the Node object, allocating memory for the drivers' list
    pub fn init(alloc: std.mem.Allocator) Node {
        return Node{ .state = false, .drivers = std.ArrayList(*Gate).init(alloc) };
    }

    /// Connect the output of a gate to this Node
    pub fn add_driver(self: *Node, gate: *Gate) !void {
        try self.drivers.append(gate);
    }

    /// Free the memory allocated within the Node
    pub fn deinit(self: *Node) void {
        self.drivers.deinit();
    }

    /// Update the state of the Node, based on the drivers' states and the selected wire function
    pub fn update(self: *Node, wire_function: WireFunction) errors.SimulationError!void {
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

            // If only one driver is allowed, return an error in case more drivers are attached
            .WireUniqueDriver => if (self.drivers.items.len == 1) self.drivers.items[0].*.output() else return errors.SimulationError.TooManyNodeDrivers,
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

    /// Initializes the Gate object. Accepts an externally allocated list of pointers to Node, takes responsibility for deallocating. Must be deinitialized using .deinit()
    pub fn init(comptime gate_type: GateType, input_nodes: std.ArrayList(*Node), external_state: ?*bool) errors.GateInitError!Self {
        const input_nodes_count = input_nodes.items.len;
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
            return errors.GateInitError.WrongNumberOfInputs;
        }

        if(gate_type == .Input and external_state == null) {
            return errors.GateInitError.MissingExternalState;
        } else if(gate_type != .Input and external_state != null) {
            return errors.GateInitError.UnnecessaryExternalState;
        }
        
        return switch(gate_type) {
            .And  => Self { .And  = input_nodes },
            .Or   => Self { .Or   = input_nodes },
            .Xor  => Self { .Xor  = input_nodes },
            .Nand => Self { .Nand = input_nodes },
            .Nor  => Self { .Nor  = input_nodes },
            .Xnor => Self { .Xnor = input_nodes },

            .Not  => Self { .Not = input_nodes },
            .Buf  => Self { .Buf = input_nodes },

            .Input => Self { .Input = external_state.? }
        };
    }

    /// Deinitializes the Gate object, freeing its memory
    pub fn deinit(self: Gate) void {
        switch(self) {
            .And, .Or, .Xor, .Nand, .Nor, .Xnor, .Not, .Buf => |*inputs| inputs.deinit(),

            else => {}
        }
    }

    /// Returns the gate's output based on the input Nodes' states and the Gate's logic function
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

/// Testing function that creates an array of 2 inputs
fn test_array_of_2_inputs(node1: *Node, node2: *Node, alloc: std.mem.Allocator) !std.ArrayList(*Node) {
    var array_of_2_inputs = std.ArrayList(*Node).init(alloc);
    try array_of_2_inputs.append(node1);
    try array_of_2_inputs.append(node2);

    return array_of_2_inputs;
}

/// Testing function that creates an array of 1 input
fn test_array_of_1_input(node: *Node, alloc: std.mem.Allocator) !std.ArrayList(*Node) {
    var array_of_1_input = std.ArrayList(*Node).init(alloc);
    try array_of_1_input.append(node);

    return array_of_1_input;
}

/// Structure representing the entire state of the Simulator
pub const Simulator = struct {
    /// List of Nodes in the circuit. Owns the memory that stores the Nodes.
    nodes: std.ArrayList(Node),
    /// List of Gates in the circuit. Owns the memory that stores the Gates.
    gates: std.ArrayList(Gate),

    /// Initializes the Simulator object. Allocates memory for the Nodes' and Gates' lists and builds the internal netlist based on the provided text representation
    pub fn init(text_netlist: [*:0]const u8, alloc: std.mem.Allocator) !Simulator {
        var simulator: Simulator = .{ 
            .nodes = std.ArrayList(Node).init(alloc),
            .gates = std.ArrayList(Gate).init(alloc) 
        };

        try simulator.parse_netlist(text_netlist);

        return simulator;
    }

    /// Deinitializes the Simulator, freeing its memory
    pub fn deinit(self: *Simulator) void {
        self.nodes.deinit();
        self.gates.deinit();
    }

    /// Takes the text representation of the netlist and transforms it into appropriately connected Nodes and Gates
    fn parse_netlist(self: *Simulator, text_netlist: [*:0]const u8) !void {

        // --TODO--

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

    /// Resets the Nodes to their initial state
    pub fn reset(self: *Simulator) void {
        _ = self;

        // --TODO--
    }

    /// Calculates the new states of all Nodes, advancing the simulation by one step
    pub fn tick(self: *Simulator) void {
        _ = self;

        // --TODO--
    }

    /// Probes for the state of a particular node
    pub fn get_node_state(self: Simulator, node_index: u32) bool {
        _ = self;
        _ = node_index;

        // --TODO--
    }
};

test "two-input logic functions" {
    // Array of all possible combinations of the inputs
    const input_scenarios = [4][2]bool{
        .{false, false}, 
        .{false, true}, 
        .{true, false}, 
        .{true, true}
    };

    std.debug.print("\n\n===============================\n", .{});
    std.debug.print("Two-input logic function tests\n", .{});
    std.debug.print("===============================\n\n", .{});

    // Go over each combination of inputs
    for(input_scenarios) |input_states| {
        // Initialize the Nodes
        var node1 = Node.init(std.testing.allocator);
        defer node1.deinit();
        var node2 = Node.init(std.testing.allocator);
        defer node2.deinit();

        // Assign the current input states to the inputs
        var input_state1 = input_states[0];
        var input_state2 = input_states[1];

        // Initialize the Inputs
        var input1 = try Gate.init(.Input, std.ArrayList(*Node).init(std.testing.allocator), &input_state1);
        defer input1.deinit();
        var input2 = try Gate.init(.Input, std.ArrayList(*Node).init(std.testing.allocator), &input_state2);
        defer input2.deinit();

        // Connect the Inputs to the Nodes
        try node1.add_driver(&input1);
        try node2.add_driver(&input2);

        // Refresh the state of the Nodes. Each node has only one driver, so .WireUniqueDriver can be used as the wire function
        try node1.update(.WireUniqueDriver);
        try node2.update(.WireUniqueDriver);

        // Initialize and connect one of each gate type
        var and_gate = try Gate.init(.And, try test_array_of_2_inputs(&node1, &node2, std.testing.allocator), null);
        defer and_gate.deinit();
        var or_gate = try Gate.init(.Or, try test_array_of_2_inputs(&node1, &node2, std.testing.allocator), null);
        defer or_gate.deinit();
        var xor_gate = try Gate.init(.Xor, try test_array_of_2_inputs(&node1, &node2, std.testing.allocator), null);
        defer xor_gate.deinit();
        var nand_gate = try Gate.init(.Nand, try test_array_of_2_inputs(&node1, &node2, std.testing.allocator), null);
        defer nand_gate.deinit();
        var nor_gate = try Gate.init(.Nor, try test_array_of_2_inputs(&node1, &node2, std.testing.allocator), null);
        defer nor_gate.deinit();
        var xnor_gate = try Gate.init(.Xnor, try test_array_of_2_inputs(&node1, &node2, std.testing.allocator), null);
        defer xnor_gate.deinit();
        var not_gate = try Gate.init(.Not, try test_array_of_1_input(&node1, std.testing.allocator), null);
        defer not_gate.deinit();
        var buf_gate = try Gate.init(.Buf, try test_array_of_1_input(&node1, std.testing.allocator), null);
        defer buf_gate.deinit();

        // Assert and print the results
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

test "wire functions" {
    // Array of all possible combinations of the inputs
    const input_scenarios = [4][2]bool {
        .{false, false}, 
        .{false, true}, 
        .{true, false}, 
        .{true, true}
    };

    // Array of all possible wire functions
    const wire_functions = [3]WireFunction{
        .WireAnd,
        .WireOr,
        .WireUniqueDriver
    };

    std.debug.print("\n\n================\n", .{});
    std.debug.print("Wire logic tests\n", .{});
    std.debug.print("================\n\n", .{});

    // Go over every combination of inputs and wire functions
    for(wire_functions) |wire_function| {
        for(input_scenarios) |input_states| {
            // Initialize a single Node
            var node = Node.init(std.testing.allocator);
            defer node.deinit();

            // Assign the current input states to the inputs
            var input_state1 = input_states[0];
            var input_state2 = input_states[1];

            // Initialize the Inputs
            var input1 = try Gate.init(.Input, std.ArrayList(*Node).init(std.testing.allocator), &input_state1);
            defer input1.deinit();
            var input2 = try Gate.init(.Input, std.ArrayList(*Node).init(std.testing.allocator), &input_state2);
            defer input2.deinit();

            // Assign both Inputs as the drivers of the same Node
            try node.add_driver(&input1);
            try node.add_driver(&input2);

            // Assert and print the results
            switch(wire_function) {
                .WireAnd => {
                    try node.update(wire_function);
                    std.debug.print("WIRE_AND: {d} and {d} = {d}\n", .{@intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(node.state)});
                    try expect(node.state == (input_state1 and input_state2));
                },
                .WireOr => {
                    try node.update(wire_function);
                    std.debug.print("WIRE_OR:  {d} or  {d} = {d}\n", .{@intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(node.state)});
                    try expect(node.state == (input_state1 or input_state2));
                },
                .WireUniqueDriver => {    
                    try expectError(errors.SimulationError.TooManyNodeDrivers, node.update(wire_function));
                    std.debug.print("WIRE_UNIQUE_DRIVER: More than 1 driver\n", .{});
                }
            }
        }
    }

    std.debug.print("\n", .{});
}
