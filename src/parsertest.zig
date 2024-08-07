const std = @import("std");

const Simulator = @import("simulator.zig").Simulator;

test "parser" {
    const text_netlist: [*:0]const u8 =
        \\@MODULE TEST {
        \\  @IN   : in_a0 in_a1 in_b0 in_b1
        \\  AND   : in_a0     in_b1     -> and_1
        \\  AND   : in_a0     in_b0     -> out_c0
        \\  AND   : in_a1     in_b0     -> and_2
        \\  AND   : in_a1     in_b1     -> and_3
        \\  XOR   : and_1     and_2     -> out_c1
        \\  AND   : and_1     and_2     -> and_4
        \\  XOR   : and_3     and_4     -> out_c2
        \\  AND   : and_3     and_4     -> out_c3 }
    ;

    _ = try Simulator.init(text_netlist, std.testing.allocator);
}
