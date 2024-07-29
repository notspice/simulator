const std = @import("std");

const Simulator = @import("../simulator.zig").Simulator;
const NodeIndex = @import("../simulator.zig").NodeIndex;
const errors = @import("../utils/errors.zig");
const stringutils = @import("../utils/stringutils.zig");
const gate = @import("../logic/gate.zig");
const node = @import("../logic/node.zig");


pub fn handleLine(simulator: *Simulator, line: []const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!void {
    // Determine line type
    const arrow_count = std.mem.count(u8, line, "->");

    switch (arrow_count) {
        0 => return handleNode(simulator, line, alloc),
        1 => {},
        else => return errors.ParserError.UnexpectedArrowCount
    }
}

pub fn handleNode(simulator: *Simulator, line: []const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!void {
    // Find the location of the colon and arrow that separate the instance, input list and output list
    const colon_index = std.mem.indexOf(u8, line, ":") orelse return errors.ParserError.ColonNotFound;
    const arrow_index = std.mem.indexOf(u8, line, "->") orelse return errors.ParserError.ArrowNotFound;

    // Slice the line contents to obtain the three sections
    const instance_section = line[0..colon_index];
    const inputs_section = line[(colon_index + 1)..arrow_index];
    const outputs_section = line[(arrow_index + 2)..];

    // Convert the instance name to pascal case so that it can be matched with the GateType variants
    const instance_name = stringutils.strip(instance_section);
    const instance_name_pascal = try stringutils.pascal(instance_name, alloc);
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
    var gate_inputs_array = std.ArrayList(NodeIndex).init(alloc);
    while (input_names.next()) |input_name| {
        const stripped_input_name = stringutils.strip(input_name);
        if (!simulator.nodes.contains(stripped_input_name)) {
            try simulator.nodes.put(stripped_input_name, node.Node.init(alloc));
        }

        if (simulator.nodes.getIndex(stripped_input_name)) |node_index| {
            try gate_inputs_array.append(node_index);
        } else {
            return errors.ParserError.NodeNotFound;
        }
    }

    // Create the new Gate object and pass the input Nodes array to it
    const created_gate = try gate.Gate.init(gate_type, gate_inputs_array);

    // Add the new Gate to the list of all Gate instances
    try simulator.gates.append(created_gate);
    const gates_len = simulator.gates.items.len;
    const last_gate_index = gates_len - 1;

    // Assign the Gate as the driver of the Nodes that are listed as its outputs
    while (output_names.next()) |output_name| {
        const stripped_output_name = stringutils.strip(output_name);
        if (!simulator.nodes.contains(stripped_output_name)) {
            try simulator.nodes.put(stripped_output_name, node.Node.init(alloc));
        }

        if (simulator.nodes.getPtr(stripped_output_name)) |node_ptr| {
            try node_ptr.*.add_driver(last_gate_index);
        } else {
            return errors.ParserError.NodeNotFound;
        }
    }
}

pub fn handleDeclaration(simulator: *Simulator, line: []const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!void {
    
}

/// Takes the text representation of the netlist and transforms it into appropriately connected Nodes and Gates
pub fn parseNetlist(simulator: *Simulator, text_netlist: [*:0]const u8, alloc: std.mem.Allocator) (errors.ParserError || std.mem.Allocator.Error)!void {
    // Convert 0-terminated string to a Zig slice.
    const text_netlist_length = std.mem.len(text_netlist);
    const text_netlist_slice = text_netlist[0..text_netlist_length];

    // Separate the input text into lines (tokens).
    var lines = std.mem.tokenizeAny(u8, text_netlist_slice, "\n");
    var line_nr: usize = 0;
    while (lines.next()) |line| : (line_nr += 1) {
        // Store the first line of the netlist file as the circuit name
        if (line_nr == 0) {
            simulator.circuit_name = line;
        } else {
            try simulator.handleLine(line, alloc);
        }
    }
}
