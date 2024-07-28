const std = @import("std");

const expect = std.testing.expect;
const expectError = std.testing.expectError;

const utils = @import("utils.zig");

const errors = @import("errors.zig");

const testutils = @import("testutils.zig");

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
    pub fn add_driver(self: *Node, gate: *Gate) std.mem.Allocator.Error!void {
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
                if ((try driver.*.output()) == false) break false;
            } else no_zeros: {
                break :no_zeros true;
            },

            // Look for any driver that outputs 1 and set the state to 1 if any were found
            // If no driver outputs 1 (all output 0), set the state to 0
            .WireOr => for (self.drivers.items) |driver| {
                if ((try driver.*.output()) == true) break true;
            } else no_zeros: {
                break :no_zeros false;
            },

            // If only one driver is allowed, return an error in case more drivers are attached
            .WireUniqueDriver => if (self.drivers.items.len == 1) (try self.drivers.items[0].*.output()) else return errors.SimulationError.TooManyNodeDrivers,
        };
    }
};

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
    const InputList = std.ArrayList(*Node);

    // Two-input gates and their inputs
    And: InputList,
    Or: InputList,
    Xor: InputList,
    Nand: InputList,
    Nor: InputList,
    Xnor: InputList,

    // One-input gates
    Not: InputList,
    Buf: InputList,

    // Input device, which also holds a reference to an externally controlled bool that indicates whether it's enabled
    Input: *bool,

    /// Initializes the Gate object. Accepts an externally allocated list of pointers to Node, takes responsibility for deallocating. Must be deinitialized using .deinit()
    pub fn init(gate_type: GateType, input_nodes: std.ArrayList(*Node), external_state: ?*bool) errors.GateInitError!Self {
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
        if (gate_type == .Input and external_state == null) {
            input_nodes.deinit();
            return errors.GateInitError.MissingExternalState;
        } else if (gate_type != .Input and external_state != null) {
            input_nodes.deinit();
            return errors.GateInitError.UnnecessaryExternalState;
        }

        // Immediately deallocate input_nodes if the Gate is an Input
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
    pub fn output(self: Self) errors.SimulationError!bool {
        switch (self) {
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
                const input = inputs.getLastOrNull() orelse return errors.SimulationError.InvalidGateConnection;
                return !input.*.state;
            },
            .Buf => |inputs| {
                const input = inputs.getLastOrNull() orelse return errors.SimulationError.InvalidGateConnection;
                return input.*.state;
            },

            // Input device
            .Input => |external_state| {
                return external_state.*;
            },
        }
    }
};

/// Testing function that creates an array of 2 inputs
fn testArrayOf2Inputs(node1: *Node, node2: *Node, alloc: std.mem.Allocator) !std.ArrayList(*Node) {
    var array_of_2_inputs = std.ArrayList(*Node).init(alloc);
    try array_of_2_inputs.append(node1);
    try array_of_2_inputs.append(node2);

    return array_of_2_inputs;
}

/// Testing function that creates an array of 1 input
fn testArrayOf1Input(node: *Node, alloc: std.mem.Allocator) !std.ArrayList(*Node) {
    var array_of_1_input = std.ArrayList(*Node).init(alloc);
    try array_of_1_input.append(node);

    return array_of_1_input;
}

/// Structure representing the entire state of the Simulator
pub const Simulator = struct {
    /// Alias for the type of this struct
    const Self = @This();

    /// Circuit name obtained from the first line of the netlist file
    circuit_name: []const u8,
    /// List of Nodes in the circuit. Owns the memory that stores the Nodes.
    nodes: std.StringArrayHashMap(Node),
    /// List of Gates in the circuit. Owns the memory that stores the Gates.
    gates: std.ArrayList(Gate),
    /// List of input states used to influence the Inputs in the circuit
    input_states: std.ArrayList(bool),

    /// Initializes the Simulator object. Allocates memory for the Nodes' and Gates' lists and builds the internal netlist based on the provided text representation
    pub fn init(text_netlist: [*:0]const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!Self {
        var simulator: Self = .{ .circuit_name = &.{}, .nodes = std.StringArrayHashMap(Node).init(alloc), .gates = std.ArrayList(Gate).init(alloc), .input_states = std.ArrayList(bool).init(alloc) };

        try simulator.parseNetlist(text_netlist, alloc);

        return simulator;
    }

    /// Deinitializes the Simulator, freeing its memory
    pub fn deinit(self: *Simulator) void {
        for (self.nodes.keys()) |key| {
            self.nodes.getPtr(key).?.*.deinit();
        }
        self.nodes.deinit();

        for (self.gates.items) |gate| {
            gate.deinit();
        }
        self.gates.deinit();
        self.input_states.deinit();
    }

    fn handleLine(self: *Self, line: []const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!void {
        // Find the location of the colon and arrow that separate the instance, input list and output list
        const colon_index = std.mem.indexOf(u8, line, ":") orelse return errors.ParserError.ColonNotFound;
        const arrow_index = std.mem.indexOf(u8, line, "->") orelse return errors.ParserError.ArrowNotFound;

        // Slice the line contents to obtain the three sections
        const instance_section = line[0..colon_index];
        const inputs_section = line[(colon_index + 1)..arrow_index];
        const outputs_section = line[(arrow_index + 2)..];

        // Convert the instance name to pascal case so that it can be matched with the GateType variants
        const instance_name = utils.strip(instance_section);
        const instance_name_pascal = try utils.pascal(instance_name, alloc);
        defer alloc.free(instance_name_pascal);

        // Create iterators over the input and output lists
        var input_names = std.mem.tokenizeAny(u8, inputs_section, " ");
        var output_names = std.mem.tokenizeAny(u8, outputs_section, " ");

        // Parse the instance_name_pascal string into a GateType enum variant
        const gate_type: GateType = loop: inline for (@typeInfo(GateType).Enum.fields) |field| {
            if (std.mem.eql(u8, field.name, instance_name_pascal)) {
                break :loop @enumFromInt(field.value);
            }
        } else {
            return errors.ParserError.InvalidGateInstanceName;
        };

        // Allocate the input Nodes array and fill it with Nodes, creating new ones if a given name didn't exist in the list
        var inputs_array = std.ArrayList(*Node).init(alloc);
        while (input_names.next()) |input_name| {
            const stripped_input_name = utils.strip(input_name);
            if (!self.nodes.contains(stripped_input_name)) {
                try self.nodes.put(stripped_input_name, Node.init(alloc));
            }

            if (self.nodes.getPtr(stripped_input_name)) |node_ptr| {
                try inputs_array.append(node_ptr);
            } else {
                return errors.ParserError.NodeNotFound;
            }
        }

        // Create the new Gate object and pass the input Nodes array to it
        const gate = new_gate: {
            if (gate_type == .Input) {
                try self.input_states.append(false);
                const input_states_len = self.input_states.items.len;
                const last_input_state_ptr = &self.input_states.items[input_states_len - 1];
                break :new_gate try Gate.init(gate_type, inputs_array, last_input_state_ptr);
            } else {
                break :new_gate try Gate.init(gate_type, inputs_array, null);
            }
        };

        // Add the new Gate to the list of all Gate instances
        try self.gates.append(gate);
        const gates_len = self.gates.items.len;
        const last_gate_ptr = &self.gates.items[gates_len - 1];

        // Assign the Gate as the driver of the Nodes that are listed as its outputs
        while (output_names.next()) |output_name| {
            const stripped_output_name = utils.strip(output_name);
            if (!self.nodes.contains(stripped_output_name)) {
                try self.nodes.put(stripped_output_name, Node.init(alloc));
            }

            if (self.nodes.getPtr(stripped_output_name)) |node_ptr| {
                try node_ptr.*.add_driver(last_gate_ptr);
            } else {
                return errors.ParserError.NodeNotFound;
            }
        }
    }

    /// Takes the text representation of the netlist and transforms it into appropriately connected Nodes and Gates
    fn parseNetlist(self: *Self, text_netlist: [*:0]const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!void {
        // Convert 0-terminated string to a Zig slice.
        const text_netlist_length = std.mem.len(text_netlist);
        const text_netlist_slice = text_netlist[0..text_netlist_length];

        // Separate the input text into lines (tokens).
        var lines = std.mem.tokenizeAny(u8, text_netlist_slice, "\n");
        var line_nr: usize = 0;
        while (lines.next()) |line| : (line_nr += 1) {
            // Store the first line of the netlist file as the circuit name
            if (line_nr == 0) {
                self.circuit_name = line;
            } else {
                try self.handleLine(line, alloc);
            }
        }
    }

    /// Resets the Nodes to their initial state
    pub fn reset(self: *Self) void {
        _ = self;

        // --TODO--
    }

    /// Calculates the new states of all Nodes, advancing the simulation by one step
    pub fn tick(self: *Self) errors.SimulationError!void {
        for (self.nodes.keys()) |key| {
            try self.nodes.getPtr(key).?.*.update(.WireOr);
        }
    }

    /// Probes for the state of a particular node
    pub fn getNodeState(self: Self, node_index: u32) bool {
        _ = self;
        _ = node_index;

        // --TODO--
    }
};

test "two-input logic functions" {
    // Array of all possible combinations of the inputs
    const input_scenarios = [4][2]bool{ .{ false, false }, .{ false, true }, .{ true, false }, .{ true, true } };

    testutils.testTitle("Two-input logic function tests");

    // Go over each combination of inputs
    for (input_scenarios) |input_states| {
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
        var and_gate = try Gate.init(.And, try testArrayOf2Inputs(&node1, &node2, std.testing.allocator), null);
        defer and_gate.deinit();
        var or_gate = try Gate.init(.Or, try testArrayOf2Inputs(&node1, &node2, std.testing.allocator), null);
        defer or_gate.deinit();
        var xor_gate = try Gate.init(.Xor, try testArrayOf2Inputs(&node1, &node2, std.testing.allocator), null);
        defer xor_gate.deinit();
        var nand_gate = try Gate.init(.Nand, try testArrayOf2Inputs(&node1, &node2, std.testing.allocator), null);
        defer nand_gate.deinit();
        var nor_gate = try Gate.init(.Nor, try testArrayOf2Inputs(&node1, &node2, std.testing.allocator), null);
        defer nor_gate.deinit();
        var xnor_gate = try Gate.init(.Xnor, try testArrayOf2Inputs(&node1, &node2, std.testing.allocator), null);
        defer xnor_gate.deinit();
        var not_gate = try Gate.init(.Not, try testArrayOf1Input(&node1, std.testing.allocator), null);
        defer not_gate.deinit();
        var buf_gate = try Gate.init(.Buf, try testArrayOf1Input(&node1, std.testing.allocator), null);
        defer buf_gate.deinit();

        // Assert and print the results
        std.debug.print("Inputs: <{}, {}>\n", .{ @intFromBool(input_state1), @intFromBool(input_state2) });
        std.debug.print("AND:  {d} and  {d} = {d}\n", .{ @intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(try and_gate.output()) });
        try expect((try and_gate.output()) == (input_state1 and input_state2));
        std.debug.print("OR:   {d} or   {d} = {d}\n", .{ @intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(try or_gate.output()) });
        try expect((try or_gate.output()) == (input_state1 or input_state2));
        std.debug.print("XOR:  {d} xor  {d} = {d}\n", .{ @intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(try xor_gate.output()) });
        try expect((try xor_gate.output()) == ((input_state1 and !input_state2) or (!input_state1 and input_state2)));
        std.debug.print("NAND: {d} nand {d} = {d}\n", .{ @intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(try nand_gate.output()) });
        try expect((try nand_gate.output()) == !(input_state1 and input_state2));
        std.debug.print("NOR:  {d} nor  {d} = {d}\n", .{ @intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(try nor_gate.output()) });
        try expect((try nor_gate.output()) == !(input_state1 or input_state2));
        std.debug.print("XNOR: {d} xnor {d} = {d}\n", .{ @intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(try xnor_gate.output()) });
        try expect((try xnor_gate.output()) == !((input_state1 and !input_state2) or (!input_state1 and input_state2)));
        std.debug.print("NOT:     not {d} = {d}\n", .{ @intFromBool(input_state1), @intFromBool(try not_gate.output()) });
        try expect((try not_gate.output()) == !input_state1);
        std.debug.print("BUF:         {d} = {d}\n\n", .{ @intFromBool(input_state1), @intFromBool(try buf_gate.output()) });
        try expect((try buf_gate.output()) == input_state1);
    }
}

test "wire functions" {
    // Array of all possible combinations of the inputs
    const input_scenarios = [4][2]bool{ .{ false, false }, .{ false, true }, .{ true, false }, .{ true, true } };

    // Array of all possible wire functions
    const wire_functions = [3]WireFunction{ .WireAnd, .WireOr, .WireUniqueDriver };

    testutils.testTitle("Wire logic tests");

    // Go over every combination of inputs and wire functions
    for (wire_functions) |wire_function| {
        for (input_scenarios) |input_states| {
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
            switch (wire_function) {
                .WireAnd => {
                    try node.update(wire_function);
                    std.debug.print("WIRE_AND: {d} and {d} = {d}\n", .{ @intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(node.state) });
                    try expect(node.state == (input_state1 and input_state2));
                },
                .WireOr => {
                    try node.update(wire_function);
                    std.debug.print("WIRE_OR:  {d} or  {d} = {d}\n", .{ @intFromBool(input_state1), @intFromBool(input_state2), @intFromBool(node.state) });
                    try expect(node.state == (input_state1 or input_state2));
                },
                .WireUniqueDriver => {
                    try expectError(errors.SimulationError.TooManyNodeDrivers, node.update(wire_function));
                    std.debug.print("WIRE_UNIQUE_DRIVER: More than 1 driver\n", .{});
                },
            }
        }
    }

    std.debug.print("\n", .{});
}
