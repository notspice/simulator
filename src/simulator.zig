const std = @import("std");

const errors = @import("utils/errors.zig");
const node = @import("logic/node.zig");
const gate = @import("logic/gate.zig");
const utils = @import("utils/stringutils.zig");

const expect = std.testing.expect;
const expectError = std.testing.expectError;

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
    /// List of input states used to influence the Inputs in the circuit
    ports: std.ArrayList(bool),

    /// Initializes the Simulator object. Allocates memory for the Nodes' and Gates' lists and builds the internal netlist based on the provided text representation
    pub fn init(text_netlist: [*:0]const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!Self {
        var simulator: Self = .{
            .circuit_name = &.{},
            .nodes = std.StringArrayHashMap(node.Node).init(alloc),
            .gates = std.ArrayList(gate.Gate).init(alloc),
            .ports = std.ArrayList(bool).init(alloc)
        };

        try simulator.parseNetlist(text_netlist, alloc);

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
        self.ports.deinit();
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
        const gate_type: gate.GateType = loop: inline for (@typeInfo(gate.GateType).Enum.fields) |field| {
            if (std.mem.eql(u8, field.name, instance_name_pascal)) {
                break :loop @enumFromInt(field.value);
            }
        } else {
            return errors.ParserError.InvalidGateInstanceName;
        };

        // Allocate the input Nodes array and fill it with Nodes, creating new ones if a given name didn't exist in the list
        var inputs_array = std.ArrayList(node.NodeIndex).init(alloc);
        while (input_names.next()) |input_name| {
            const stripped_input_name = utils.strip(input_name);
            if (!self.nodes.contains(stripped_input_name)) {
                try self.nodes.put(stripped_input_name, node.Node.init(alloc));
            }

            if (self.nodes.getIndex(stripped_input_name)) |node_index| {
                try inputs_array.append(node_index);
            } else {
                return errors.ParserError.NodeNotFound;
            }
        }

        // Create the new Gate object and pass the input Nodes array to it
        const created_gate = new_gate: {
            if (gate_type == .Input) {
                try self.ports.append(false);
                const ports_len = self.ports.items.len;
                const last_port_index = ports_len - 1;
                break :new_gate try gate.Gate.init(gate_type, inputs_array, last_port_index);
            } else {
                break :new_gate try gate.Gate.init(gate_type, inputs_array, null);
            }
        };

        // Add the new Gate to the list of all Gate instances
        try self.gates.append(created_gate);
        const gates_len = self.gates.items.len;
        const last_gate_index = gates_len - 1;

        // Assign the Gate as the driver of the Nodes that are listed as its outputs
        while (output_names.next()) |output_name| {
            const stripped_output_name = utils.strip(output_name);
            if (!self.nodes.contains(stripped_output_name)) {
                try self.nodes.put(stripped_output_name, node.Node.init(alloc));
            }

            if (self.nodes.getPtr(stripped_output_name)) |node_ptr| {
                try node_ptr.*.add_driver(last_gate_index);
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
            try self.nodes.getPtr(key).?.*.update(.WireOr, &self.gates, &self.nodes, &self.ports);
        }
    }

    /// Probes for the state of a particular node
    pub fn getNodeState(self: Self, node_index: u32) bool {
        _ = self;
        _ = node_index;

        // --TODO--
    }
};
