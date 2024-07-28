const std = @import("std");

const api = @import("api.zig");

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
        .{false, false, false},
        .{false, false, true},
        .{false, true,  false},
        .{false, true,  true},
        .{true,  false, false},
        .{true,  false, true},
        .{true,  true,  false},
        .{true,  true,  true},
    };

    std.debug.print("\n\n===============\n", .{});
    std.debug.print("Full adder test\n", .{});
    std.debug.print("===============\n\n", .{});

    for(input_scenarios) |input_scenario| {
        var simulator = try api.Simulator.init(text_netlist, std.testing.allocator);
        defer simulator.deinit();

        simulator.input_states.items[0] = input_scenario[0];
        simulator.input_states.items[1] = input_scenario[1];
        simulator.input_states.items[2] = input_scenario[2];

        try simulator.tick();
        try simulator.tick();
        try simulator.tick();
        try simulator.tick();

        std.debug.print("Inputs: <{d} {d} {d}>\nCarry out: {d} Sum: {d}\n\n", .{
            @intFromBool(simulator.input_states.items[0]),
            @intFromBool(simulator.input_states.items[1]),
            @intFromBool(simulator.input_states.items[2]),

            @intFromBool(simulator.nodes.get("out_carry").?.state),
            @intFromBool(simulator.nodes.get("out_sum").?.state)
        });
    }
}
