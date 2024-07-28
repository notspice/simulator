const std = @import("std");

const api = @import("api.zig");

const testutils = @import("testutils.zig");

pub fn main() !void {
    // var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    // const alloc = gpa.allocator();
}

test "adder" {
    const text_netlist: [*:0]const u8 =
        \\Full adder
        \\INPUT :                     -> in_a
        \\INPUT :                     -> in_b
        \\INPUT :                     -> in_carry
        \\AND   : in_a      in_b      -> carry_1st
        \\XOR   : in_a      in_b      -> half_sum
        \\AND   : half_sum  in_carry  -> carry_2nd
        \\XOR   : half_sum  in_carry  -> out_sum
        \\OR    : carry_1st carry_2nd -> out_carry
    ;

    const input_scenarios = [8][3]bool{
        .{ false, false, false },
        .{ false, false, true },
        .{ false, true, false },
        .{ false, true, true },
        .{ true, false, false },
        .{ true, false, true },
        .{ true, true, false },
        .{ true, true, true },
    };

    testutils.testTitle("Full adder test");

    for (input_scenarios) |input_scenario| {
        var simulator = try api.Simulator.init(text_netlist, std.testing.allocator);
        defer simulator.deinit();

        simulator.input_states.items[0] = input_scenario[0];
        simulator.input_states.items[1] = input_scenario[1];
        simulator.input_states.items[2] = input_scenario[2];

        try simulator.tick();
        try simulator.tick();
        try simulator.tick();
        try simulator.tick();

        std.debug.print("Inputs: <{d} {d} {d}>\nCarry out: {d} Sum: {d}\n\n", .{ @intFromBool(simulator.input_states.items[0]), @intFromBool(simulator.input_states.items[1]), @intFromBool(simulator.input_states.items[2]), @intFromBool(simulator.node_names.get("out_carry").?.*.state), @intFromBool(simulator.node_names.get("out_sum").?.*.state) });
    }
}

test "2-bit multiplier" {
    const text_netlist: [*:0]const u8 =
        \\2-bit multiplier
        \\INPUT :                     -> in_a0
        \\INPUT :                     -> in_a1 
        \\INPUT :                     -> in_b0
        \\INPUT :                     -> in_b1
        \\AND   : in_a0     in_b0     -> carry_1st
        \\AND   : in_a0     in_b1     -> out_c0
        \\AND   : in_a1     in_b0     -> carry_2nd
        \\AND   : in_a1     in_b1     -> carry_3rd
        \\XOR   : carry_1st carry_2nd -> out_c1
        \\AND   : carry_1st carry_2nd -> carry_4th
        \\XOR   : carry_3rd carry_4th -> out_c2
        \\AND   : carry_3rd carry_4th -> out_c3
    ;

    const input_scenarios = [16][4]bool{
        .{ false, false, false, false },
        .{ false, false, false, true },
        .{ false, false, true, false },
        .{ false, false, true, true },
        .{ false, true, false, false },
        .{ false, true, false, true },
        .{ false, true, true, false },
        .{ false, true, true, true },
        .{ true, false, false, false },
        .{ true, false, false, true },
        .{ true, false, true, false },
        .{ true, false, true, true },
        .{ true, true, false, false },
        .{ true, true, false, true },
        .{ true, true, true, false },
        .{ true, true, true, true },
    };

    testutils.testTitle("Full adder test");

    for (input_scenarios) |input_scenario| {
        var simulator = try api.Simulator.init(text_netlist, std.testing.allocator);
        defer simulator.deinit();

        simulator.input_states.items[0] = input_scenario[0];
        simulator.input_states.items[1] = input_scenario[1];
        simulator.input_states.items[2] = input_scenario[2];
        simulator.input_states.items[3] = input_scenario[3];

        try simulator.tick();
        try simulator.tick();
        try simulator.tick();
        try simulator.tick();

        std.debug.print("Inputs: <{d} {d} {d} {d}>\nOutput: <{d} {d} {d} {d}>\n\n", .{ @intFromBool(simulator.input_states.items[0]), @intFromBool(simulator.input_states.items[1]), @intFromBool(simulator.input_states.items[2]), @intFromBool(simulator.input_states.items[3]), @intFromBool(simulator.node_names.get("out_c0").?.*.state), @intFromBool(simulator.node_names.get("out_c1").?.*.state), @intFromBool(simulator.node_names.get("out_c2").?.*.state), @intFromBool(simulator.node_names.get("out_c3").?.*.state) });
    }
}
