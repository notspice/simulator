const std = @import("std");
const testutils = @import("utils/testutils.zig");

const expect = std.testing.expect;
const expectError = std.testing.expectError;

const Simulator = @import("simulator.zig").Simulator;

test "parser" {
    const text_netlist: [*:0]const u8 =
        \\@MODULE multiplexer {
        // \\INPUT :                     -> in_a1
        // \\INPUT :                     -> in_a0
        // \\INPUT :                     -> in_b1
        // \\INPUT :                     -> in_b0
        \\AND   : in_a0     in_b1     -> and_1;
        \\AND   : in_a0     in_b0     -> out_c0;
        \\AND   : in_a1     in_b0     -> and_2;
        \\AND   : in_a1     in_b1     -> and_3;
        \\XOR   : and_1     and_2     -> out_c1;
        \\AND   : and_1     and_2     -> and_4;
        \\XOR   : and_3     and_4     -> out_c2;
        \\AND   : and_3     and_4     -> out_c3;
        \\} @MODULE multiplexer2 test aaaa {
        // \\INPUT :                     -> in_a1
        // \\INPUT :                     -> in_a0
        // \\INPUT :                     -> in_b1
        // \\INPUT :                     -> in_b0
        \\AND   : in_a0     in_b1     -> and_1;
        \\AND   : in_a0     in_b0     -> out_c0;
        \\AND   : in_a1     in_b0     -> and_2;
        \\AND   : in_a1     in_b1     -> and_3;
        \\XOR   : and_1     and_2     -> out_c1;
        \\AND   : and_1     and_2     -> and_4;
        \\XOR   : and_3     and_4     -> out_c2;
        \\AND   : and_3     and_4     -> out_c3;
        \\}
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

    testutils.testTitle("Multiplier test");

    for (0.., input_scenarios[0..1]) |i, input_scenario| {
        var simulator = try Simulator.init(text_netlist, std.testing.allocator);
        defer simulator.deinit();

        _ = i;
        _ = outputs;

        simulator.setNodeStateString("in_a1", input_scenario[0]);
        simulator.setNodeStateString("in_a0", input_scenario[1]);
        simulator.setNodeStateString("in_b1", input_scenario[2]);
        simulator.setNodeStateString("in_b0", input_scenario[3]);

        std.debug.print("Inputs: <{d} {d} {d} {d}>\nOutput: <{d} {d} {d} {d}>\n\n", .{
            @intFromBool(simulator.getNodeStateString("in_a1")),
            @intFromBool(simulator.getNodeStateString("in_a0")),
            @intFromBool(simulator.getNodeStateString("in_b1")),
            @intFromBool(simulator.getNodeStateString("in_b0")),
            @intFromBool(simulator.getNodeStateString("out_c3")),
            @intFromBool(simulator.getNodeStateString("out_c2")),
            @intFromBool(simulator.getNodeStateString("out_c1")),
            @intFromBool(simulator.getNodeStateString("out_c0"))
        });

        try simulator.tick();
        // try simulator.tick();
        // try simulator.tick();
        // try simulator.tick();

        // try expect(simulator.getNodeStateString("out_c3") == outputs[i][0]);
        // try expect(simulator.getNodeStateString("out_c2") == outputs[i][1]);
        // try expect(simulator.getNodeStateString("out_c1") == outputs[i][2]);
        // try expect(simulator.getNodeStateString("out_c0") == outputs[i][3]);

        std.debug.print("Inputs: <{d} {d} {d} {d}>\nOutput: <{d} {d} {d} {d}>\n\n", .{
            @intFromBool(simulator.getNodeStateString("in_a1")),
            @intFromBool(simulator.getNodeStateString("in_a0")),
            @intFromBool(simulator.getNodeStateString("in_b1")),
            @intFromBool(simulator.getNodeStateString("in_b0")),
            @intFromBool(simulator.getNodeStateString("out_c3")),
            @intFromBool(simulator.getNodeStateString("out_c2")),
            @intFromBool(simulator.getNodeStateString("out_c1")),
            @intFromBool(simulator.getNodeStateString("out_c0"))
        });
    }
}