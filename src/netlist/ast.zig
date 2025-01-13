const std = @import("std");


const errors = @import("utils/errors.zig");
const node = @import("logic/node.zig");
const gate = @import("logic/gate.zig");


pub const NodeAst = struct {
    const Self = @This();

    node_type: node.NodeType,
    name: std.ArrayList(u8),
};

pub const GateAst = struct {
    const Self = @This();

    gate_type: gate.GateType,

    /// names of the input nodes
    input_nodes: std.BufSet(),
    name: std.ArrayList(u8),
};

pub const Module = struct {
    const Self = @This();
    
    name: std.ArrayList(u8),

    /// gates & other modules
    inner_modules: std.ArrayList(Module),

    /// gates in this module
    gates: std.ArrayList(GateAst),

    /// internal nodes in this module
    nodes: std.ArrayList(NodeAst),

    input_nodes: std.ArrayList(NodeAst),

    output_nodes: std.ArrayList(NodeAst),


    fn allNodes(self: Self, alloc: std.mem.Allocator) std.ArrayList(NodeAst) {
        var nodes = std.ArrayList(NodeAst).init(alloc);

        for(self.inner_modules.values()) | module | {
            const inner_nodes = module.allNodes(alloc);
            nodes.appendSlice(inner_nodes);
            inner_nodes.deinit();
        }

        nodes.appendSlice(self.nodes.values());
        nodes.appendSlice(self.input_nodes.values());
        nodes.appendSlice(self.output_nodes.values()); 

        return nodes;      
    }
};


pub const Netlist = struct {
    const Self = @This();

    circuit_name: std.ArrayList(u8),

};















