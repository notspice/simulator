const std = @import("std");

const api = @import("simulator/api.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const text_netlist: [*:0]const u8 =
        \\NOR N1 N2
        \\AND N2 N3
    ;

    var simulator = try api.Simulator.init(text_netlist, alloc);
    defer simulator.deinit();

    // --TODO-- Turn the below code into a test block

    // Use wire-or logic for the example
    const wire_logic_kind = api.WireFunction.WireOr;

    // Non-const bool that's always true
    var always_true = true;
    // Non-const type bool that's always false
    var always_false = false;

    // Input instance that's always turned on
    var always_on_input = api.Gate.init(.{ .Input = &always_true }, null, null);
    // Input instance that's always turned off
    var always_off_input = api.Gate.init(.{ .Input = &always_false }, null, null);

    // Initialize 2 example Nodes
    var node_thats_turned_on = api.Node.init(alloc);
    var node_thats_turned_off = api.Node.init(alloc);

    // Assign the inputs to some Nodes. One will always be on, one always off (for the example)
    try node_thats_turned_on.add_driver(&always_on_input);
    try node_thats_turned_off.add_driver(&always_off_input);

    // Update the nodes so that they get their new states from the Inputs
    try node_thats_turned_on.update(wire_logic_kind);
    try node_thats_turned_off.update(wire_logic_kind);

    // Initialize an AND gate and connect it to the declared nodes
    // Try changing the gates and the nodes to something else
    var gate = api.Gate.init(.And, &node_thats_turned_on, &node_thats_turned_on);

    // Get the gate's output and display it
    const value = gate.output();

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{}", .{value});
}
