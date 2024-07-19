const std = @import("std");

/// Logic function performed by the wire
const WireFunction = enum {
    /// If all drivers output 1, the wire's state is 1
    WireAnd,
    /// If at least one driver outputs 1, the wire's state is 1
    WireOr,
    /// Only one gate is allowed to drive this wire, conflicts are resolved before simulation
    WireUniqueDriver
};


/// The logical circuit node (wire). 
/// 
/// The Node is where the state of the circuit is remembered between ticks
const Node = struct {
    /// Current state of the node, referenced by connected gates' inputs
    state: bool,
    /// List of references to gates that drive this Node
    drivers: std.ArrayList(*Gate),

    /// Initialize the Node object, allocating memory for the drivers' list
    fn init(alloc: std.mem.Allocator) Node {
        return Node {
            .state = false,
            .drivers = std.ArrayList(*Gate).init(alloc)
        };
    }

    /// Free the memory allocated within the Node
    fn deinit(self: *Node) void {
        self.drivers.deinit();
    }

    /// Update the state of the Node, based on the drivers' states and the selected wire function
    fn update(self: *Node, wire_function: WireFunction) void {
        self.state = switch(wire_function) {
            .WireAnd          => false, // --TODO--
            .WireOr           => false, // --TODO--
            .WireUniqueDriver => false  // --TODO--
        };
    }
};


/// Type of a logic gate that determines its function
const GateType = union(enum) {
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

    // Input device, which holds a reference to an externally controlled bool that indicates whether it's enabled
    Input: *bool
};


const Gate = struct {
    /// Gate type
    gate_type: GateType,

    /// Optional reference to the Node that is connected to the gate's first input. If null, the input doesn't exist in a given gate.
    input_a_node: ?*Node,
    /// Optional reference to the Node that is connected to the gate's second input. If null, the input doesn't exist in a given gate.
    input_b_node: ?*Node,

    /// Get the gate's output based on the input Nodes' states and the gate's logic function
    fn output(self: Gate) bool {
        const input_a_state = self.input_a_node.?.state orelse false;
        const input_b_state = self.input_b_node.?.state orelse false;

        return switch(self.gate_type) {
            // Two-input gates
            .And   =>   input_a_state & input_b_state,
            .Or    =>   input_a_state | input_b_state,
            .Xor   =>   input_a_state ^ input_b_state,
            .Nand  => !(input_a_state & input_b_state),
            .Nor   => !(input_a_state | input_b_state),
            .Xnor  => !(input_a_state ^ input_b_state),

            // One-input gates
            .Not   =>  !input_a_state,
            .Buf   =>   input_a_state,

            // input device
            .Input => |input_state| input_state
        };
    }

    /// Initialize a new Gate object
    fn init(gate_type: GateType, input_a_node: ?*Node, input_b_node: ?*Node) Gate {
        return Gate {
            .gate_type = gate_type,
            .input_a_node = input_a_node,
            .input_b_node = input_b_node
        };
    }
};


/// Structure representing the entire state of the Simulator
pub const Simulator = struct {
    /// Map of Nodes and their IDs. Owns the memory that stores the Nodes.
    nodes: std.AutoHashMap(usize, Node),
    /// List of gates within the circuit. Owns the memory that stores the Gates.
    gates: std.ArrayList(Gate),

    /// Initialize the Simulator object. 
    /// 
    /// Allocates memory for the Nodes' and Gates' collections and builds the internal netlist based on the provided text representation
    pub fn init(text_netlist: [*:0]const u8, alloc: std.mem.Allocator) !Simulator {
        var simulator: Simulator = .{
            .nodes = std.AutoHashMap(usize, Node).init(alloc),
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
        _ = text_netlist;

        // --TODO--
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
