const std = @import("std");

const expect = std.testing.expect;

const testutils = @import("utils/testutils.zig");
const Simulator = @import("simulator.zig").Simulator;

pub fn main() !void {
    std.debug.print(":)", .{});
}

test "2-bit multiplier" {
    const text_netlist: [*:0]const u8 =
        \\2-bit multiplier
        \\AND : in_a0 in_b1 -> and_1
        \\AND : in_a0 in_b0 -> out_c0
        \\AND : in_a1 in_b0 -> and_2
        \\AND : in_a1 in_b1 -> and_3
        \\XOR : and_1 and_2 -> out_c1
        \\AND : and_1 and_2 -> and_4
        \\XOR : and_3 and_4 -> out_c2
        \\AND : and_3 and_4 -> out_c3
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

    const outputs: [16][4]bool = [16][4]bool {
        .{ false, false, false, false },
        .{ false, false, false, false },
        .{ false, false, false, false },
        .{ false, false, false, false },
        .{ false, false, false, false },
        .{ false, false, false, true },
        .{ false, false, true, false },
        .{ false, false, true, true },
        .{ false, false, false, false },
        .{ false, false, true, false },
        .{ false, true, false, false },
        .{ false, true, true, false },
        .{ false, false, false, false },
        .{ false, false, true, true },
        .{ false, true, true, false },
        .{ true, false, false, true }
    };

    testutils.testTitle("2-bit multiplier test");

    for (0.., input_scenarios) |i, input_scenario| {
        var simulator = try Simulator.init(text_netlist, std.testing.allocator);
        defer simulator.deinit();

        // std.debug.print("Keys:\n", .{});
        // for(simulator.nodes.keys()) |key| {
        //     std.debug.print("State: {any}\n", .{simulator.nodes.getPtr(key).?.*.state});
        // }

        simulator.nodes.getPtr("in_a1").?.*.new_state = input_scenario[0];
        simulator.nodes.getPtr("in_a0").?.*.new_state = input_scenario[1];
        simulator.nodes.getPtr("in_b1").?.*.new_state = input_scenario[2];
        simulator.nodes.getPtr("in_b0").?.*.new_state = input_scenario[3];

        try simulator.tick();
        try simulator.tick();
        try simulator.tick();
        try simulator.tick();

        testutils.printAllNodeStates(&simulator);

        try expect(simulator.nodes.get("out_c3").?.state == outputs[i][0]);
        try expect(simulator.nodes.get("out_c2").?.state == outputs[i][1]);
        try expect(simulator.nodes.get("out_c1").?.state == outputs[i][2]);
        try expect(simulator.nodes.get("out_c0").?.state == outputs[i][3]);
    }
}

test "4-bit CLABA test" {
    const text_netlist: [*:0]const u8 = 
        \\4-bit carry lookahead binary adder
        \\XOR   : in_a0 in_b0                       -> xor_0
        \\AND   : in_a0 in_b0                       -> and_0
        \\XOR   : in_a1 in_b1                       -> xor_1
        \\AND   : in_a1 in_b1                       -> and_1
        \\XOR   : in_a2 in_b2                       -> xor_2
        \\AND   : in_a2 in_b2                       -> and_2
        \\XOR   : in_a3 in_b3                       -> xor_3
        \\AND   : in_a3 in_b3                       -> and_3
        \\XOR   : xor_0 in_carry                    -> xor_4
        \\XOR   : or_0 xor_1                        -> xor_5
        \\XOR   : or_1 xor_2                        -> xor_6
        \\XOR   : or_2 xor_3                        -> xor_7
        \\OR    : and_0 and_4                       -> or_0
        \\OR    : and_1 and_5 and_6                 -> or_1
        \\OR    : and_2 and_7 and_8 and_9           -> or_2
        \\OR    : and_3 and_10 and_11 and_12 and_13 -> or_3
        \\AND   : in_carry xor_0                    -> and_4
        \\AND   : and_0 xor_1                       -> and_5
        \\AND   : xor_0 xor_1 in_carry              -> and_6
        \\AND   : xor_2 and_1                       -> and_7
        \\AND   : xor_2 xor_1 and_0                 -> and_8
        \\AND   : xor_2 xor_1 xor_0 in_carry        -> and_9
        \\AND   : xor_3 and_2                       -> and_10
        \\AND   : xor_3 xor_2 and_1                 -> and_11
        \\AND   : xor_3 xor_2 xor_1 and_0           -> and_12
        \\AND   : xor_3 xor_2 xor_1 xor_0 in_carry  -> and_13
    ;

    var input_scenarios: [512][9] bool = undefined;
    var outputs: [512][5] bool = undefined;

    testutils.testTitle("4-bit CLABA test");

    for (0..48) |i| {
        const a = i >> 5;
        const b = (i >> 1) & 0xF;
        const carry = i & 0x1;

        input_scenarios[i] = .{ a & 0x8 == 8, a & 0x4 == 4, a & 0x2 == 2, a & 0x1 == 1, b & 0x8 == 8, b & 0x4 == 4, b & 0x2 == 2, b & 0x1 == 1, carry == 1 };

        const sum = a + b + carry;
        outputs[i] = .{ sum & 0x8 == 8, sum & 0x4 == 4, sum & 0x2 == 2, sum & 0x1 == 1, sum > 15 };

        var simulator = try Simulator.init(text_netlist, std.testing.allocator);
        defer simulator.deinit();

        std.debug.print("\n\nInput A: ", .{});
        for(input_scenarios[i][0..4]) |input| {
            std.debug.print("{d} ", .{@intFromBool(input)});
        }

        std.debug.print("\nInput B: ", .{});
        for(input_scenarios[i][4..8]) |input| {
            std.debug.print("{d} ", .{@intFromBool(input)});
        }

        std.debug.print("\nCarry: {d}", .{@intFromBool(input_scenarios[i][8])});

        try simulator.tick();

        for(0..20) |_| {
            simulator.nodes.getPtr("in_a0").?.*.new_state = input_scenarios[i][7];
            simulator.nodes.getPtr("in_a1").?.*.new_state = input_scenarios[i][6];
            simulator.nodes.getPtr("in_a2").?.*.new_state = input_scenarios[i][5];
            simulator.nodes.getPtr("in_a3").?.*.new_state = input_scenarios[i][4];
            simulator.nodes.getPtr("in_b0").?.*.new_state = input_scenarios[i][3];
            simulator.nodes.getPtr("in_b1").?.*.new_state = input_scenarios[i][2];
            simulator.nodes.getPtr("in_b2").?.*.new_state = input_scenarios[i][1];
            simulator.nodes.getPtr("in_b3").?.*.new_state = input_scenarios[i][0];
            simulator.nodes.getPtr("in_carry").?.*.new_state = input_scenarios[i][8];
            try simulator.tick();
        }

        std.debug.print("\nOutputs: {d} {d} {d} {d} {d}\n", .{
            @intFromBool(simulator.nodes.get("xor_4").?.state),
            @intFromBool(simulator.nodes.get("xor_5").?.state),
            @intFromBool(simulator.nodes.get("xor_6").?.state),
            @intFromBool(simulator.nodes.get("xor_7").?.state),
            @intFromBool(simulator.nodes.get("or_3").?.state),
        });

        //testutils.printAllNodeStates(&simulator);

         std.debug.print("Expected outputs: {d} {d} {d} {d} {d}", .{
            @intFromBool(outputs[i][3]),
            @intFromBool(outputs[i][2]),
            @intFromBool(outputs[i][1]),
            @intFromBool(outputs[i][0]),
            @intFromBool(outputs[i][4]),
        });

        try expect(simulator.nodes.get("xor_7").?.state == outputs[i][0]);
        try expect(simulator.nodes.get("xor_6").?.state == outputs[i][1]);
        try expect(simulator.nodes.get("xor_5").?.state == outputs[i][2]);
        try expect(simulator.nodes.get("xor_4").?.state == outputs[i][3]);
        try expect(simulator.nodes.get("or_3").?.state == outputs[i][4]);
    }
}

test "adder" {
    const text_netlist: [*:0]const u8 =
        \\adder
        \\AND : in_a      in_b      -> carry_1st
        \\XOR : in_a      in_b      -> half_sum
        \\AND : half_sum  in_carry  -> carry_2nd
        \\XOR : half_sum  in_carry  -> out_sum
        \\OR  : carry_1st carry_2nd -> out_carry
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

    const outputs = [8][2]bool {
        .{ false, false },
        .{ false, true },
        .{ false, true },
        .{ true, false },
        .{ false, true },
        .{ true, false },
        .{ true, false },
        .{ true, true },
    };

    testutils.testTitle("Full adder test");

    for (0.., input_scenarios) |i, input_scenario| {
        var simulator = try Simulator.init(text_netlist, std.testing.allocator);
        defer simulator.deinit();

        simulator.nodes.getPtr("in_a").?.*.new_state = input_scenario[0];
        simulator.nodes.getPtr("in_b").?.*.new_state = input_scenario[1];
        simulator.nodes.getPtr("in_carry").?.*.new_state = input_scenario[2];
        try simulator.tick();
        simulator.nodes.getPtr("in_a").?.*.new_state = input_scenario[0];
        simulator.nodes.getPtr("in_b").?.*.new_state = input_scenario[1];
        simulator.nodes.getPtr("in_carry").?.*.new_state = input_scenario[2];
        try simulator.tick();
        simulator.nodes.getPtr("in_a").?.*.new_state = input_scenario[0];
        simulator.nodes.getPtr("in_b").?.*.new_state = input_scenario[1];
        simulator.nodes.getPtr("in_carry").?.*.new_state = input_scenario[2];
        try simulator.tick();
        simulator.nodes.getPtr("in_a").?.*.new_state = input_scenario[0];
        simulator.nodes.getPtr("in_b").?.*.new_state = input_scenario[1];
        simulator.nodes.getPtr("in_carry").?.*.new_state = input_scenario[2];
        try simulator.tick();

        testutils.printAllNodeStates(&simulator);

        try expect(simulator.nodes.get("out_carry").?.state == outputs[i][0]);
        try expect(simulator.nodes.get("out_sum").?.state == outputs[i][1]);
    }
}
