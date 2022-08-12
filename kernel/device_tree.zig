const std = @import("std");
extern fn printf([*:0]const u8, ...) void;

// _dtb stores the address of the device tree
export var _dtb: *FdtHeader = undefined;
const FdtHeader = struct {
    magic: u32,
    totalsize: u32,
    off_dt_struct: u32,
    off_dt_strings: u32,
    off_mem_rsvmap: u32,
    version: u32,
    last_comp_version: u32,
    boot_cpuid_phys: u32,
    size_dt_strings: u32,
    size_dt_struct: u32,
    fn dt_raw_ptr() [*]u8 {
        return @ptrCast([*]u8, _dtb);
    }
    fn dt_struct(dt_offset: usize) u32 {
        const ptr = dt_raw_ptr() + dtb_uint(_dtb.*.off_dt_struct) + dt_offset;
        return dtb_uint(@ptrCast(*u32, @alignCast(4, ptr)).*);
    }
    fn dt_string() [*]u8 {
        return dt_raw_ptr() + dtb_uint(_dtb.*.off_dt_strings);
    }
};

fn dtb_uint(x: u32) u32 {
    return (((x) & 0xff000000) >> 24) |
        (((x) & 0x00ff0000) >> 8) |
        (((x) & 0x0000ff00) << 8) |
        (((x) & 0x000000ff) << 24);
}

fn roundup(x: usize) usize {
    var rem: usize = x % 4;
    return if (rem == 0) x else x - rem + 4;
}
fn dtb_name(arg_name_offset: u32) [*c]u8 {
    var name_offset = arg_name_offset;
    return FdtHeader.dt_string() + name_offset;
}
fn print_level_indent(level: u32) void {
    var i: u32 = 0;
    while (i < level) : (i += 1) {
        printf("  ");
    }
}

export fn walk_device_tree() void {
    printf("_dtb: %p\n", _dtb);
    printf("magic: %p\n", dtb_uint(_dtb.magic));
    printf("struct: %p\n", dtb_uint(_dtb.off_dt_struct));
    walk_device_tree_iter(0, DtNodeIter.root());

    printf("memory:\n");
    if (DtNodeIter.root().find("/memory@80000000")) |node| {
        printf("Found\n");
        var props = node.properties;
        while (props.next()) |prop| {
            print_property(prop);
        }
    } else {
        printf("Not found\n");
    }
}
fn walk_device_tree_iter(level: u32, iter_arg: DtNodeIter) void {
    var iter = iter_arg;
    while (iter.next()) |node| {
        print_level_indent(level);
        printf("Node: %s\n", node.name.ptr);
        var props = node.properties;
        while (props.next()) |prop| {
            print_level_indent(level + 1);
            print_property(prop);
        }
        walk_device_tree_iter(level + 1, node.children);
    }
}
fn print_property(prop: DtProp) void {
    printf(".%s: ", prop.name.ptr);
    switch (prop.value) {
        .u32 => |val| printf("(u32) %d", val),
        .u64 => |val| printf("(u64) %d", val),
        .reg => |val| {
            printf("(reg %d,%d) ", val.address_cells, val.size_cells);
            printf("< ");
            var iter = val;
            while (iter.next()) |block| {
                printf("%p ", block.offset);
                if (block.size) |size| {
                    printf("%x ", size);
                } else {
                    printf("- ");
                }
            }
            printf(">");
        },
        .string => |val| printf("(string) \"%s\"", val),
        .stringlist => |list| {
            printf("(stringlist) ");
            var iter = list;
            var first = true;
            while (iter.next()) |str| {
                if (first) {
                    first = false;
                } else {
                    printf(", ");
                }
                printf("\"%s\"", str.ptr);
            }
        },
        .empty => printf("(empty)"),
        .phandle => |handle| printf("(handle) %d", handle),
        .unknown => {
            printf("(unknown) ");
            for (prop.raw_value) |val| {
                printf(" %x", @intCast(u32, val));
            }
        },
    }
    printf("\n");
}
fn be_int(comptime T: type, value: []const u8) T {
    var scratch: T = 0;
    for (value) |v| {
        scratch = (scratch << 8) | v;
    }
    return scratch;
}

const FDT = struct {
    const BEGIN_NODE = 0x1;
    const END_NODE = 0x2;
    const PROP = 0x3;
    const END = 0x9;
};
const DtNode = struct {
    name: [:0]u8,
    properties: DtPropIter,
    children: DtNodeIter,
    fn map_props(self: DtNode, func: fn (name: []u8, value: []u8) void) void {
        var props = self.properties;
        while (props.next()) |prop| {
            func(prop.name, prop.value);
        }
    }
};
const DtNodeIter = struct {
    dt_offset: usize,
    address_cells: u32,
    size_cells: u32,
    fn root() DtNodeIter {
        return DtNodeIter{ .dt_offset = 0, .address_cells = 2, .size_cells = 1 };
    }
    fn next(self: *DtNodeIter) ?DtNode {
        var node: DtNode = undefined;
        if (FdtHeader.dt_struct(self.dt_offset) != FDT.BEGIN_NODE) {
            return null;
        }
        self.dt_offset += 4; // FDT_BEGIN_NODE
        node.name = std.mem.span(@ptrCast([*:0]u8, FdtHeader.dt_raw_ptr()) + dtb_uint(_dtb.*.off_dt_struct) + self.dt_offset);
        self.dt_offset += node.name.len + 1; // name
        self.dt_offset = roundup(self.dt_offset);

        node.properties = DtPropIter{ .dt_offset = self.dt_offset, .address_cells = self.address_cells, .size_cells = self.size_cells };

        var address_cells: u32 = 2;
        var size_cells: u32 = 1;
        var props = node.properties;
        while (props.next()) |prop| {
            if (std.mem.eql(u8, "#address-cells", prop.name)) {
                address_cells = prop.value.u32;
            } else if (std.mem.eql(u8, "#size-cells", prop.name)) {
                size_cells = prop.value.u32;
            }
        }
        self.dt_offset = props.dt_offset;

        node.children = DtNodeIter{ .dt_offset = self.dt_offset, .address_cells = address_cells, .size_cells = size_cells };
        var children = node.children;
        while (children.next() != null) {}
        self.dt_offset = children.dt_offset; // children
        self.dt_offset += 4; // FDT_END_NODE
        return node;
    }
    fn find(self: DtNodeIter, filter: []const u8) ?DtNode {
        var iter = self;
        var split = std.mem.split(u8, filter, "/");
        const name = split.first();
        const search_end_node = filter.len == name.len;
        while (iter.next()) |node| {
            if (!std.mem.eql(u8, name, node.name)) {
                continue;
            } else if (search_end_node) {
                return node;
            } else {
                return find(node.children, split.rest());
            }
        }
        return null;
    }
};

const DtProp = struct {
    name: [:0]u8,
    value: Value,
    raw_value: []u8,
    address_cells: u32,
    size_cells: u32,
    const ValueType = enum {
        // standard types:
        empty,
        u32,
        u64,
        string,
        phandle,
        stringlist,
        // prop-encoded-arrays:
        reg,
        // otherwise
        unknown,
    };
    const Value = union(ValueType) {
        // standard types:
        empty,
        u32: u32,
        u64: u64,
        string: [*:0]const u8,
        phandle: u32,
        stringlist: std.mem.SplitIterator(u8),
        // prop-encoded-arrays:
        reg: Reg,
        // otherwise
        unknown,
    };
    const Reg = struct {
        prop_value: []const u8,
        address_cells: u32,
        size_cells: u32,
        pair_n: usize,
        const Block = struct {
            offset: u64,
            size: ?u64,
        };
        fn next(self: *Reg) ?Block {
            const address_size = self.address_cells * 4;
            const size_size = self.size_cells * 4;
            const pair_size = address_size + size_size;

            if (self.pair_n >= self.prop_value.len / pair_size) {
                return null;
            }
            const pair = self.prop_value[pair_size * self.pair_n .. pair_size * (self.pair_n + 1)];

            var block: Block = .{ .offset = 0, .size = null };
            for (pair[0..address_size]) |v| {
                block.offset = (block.offset << 8) | v;
            }
            if (self.size_cells != 0) {
                block.size = 0;
                for (pair[address_size..]) |v| {
                    block.size = (block.size.? << 8) | v;
                }
            }
            self.pair_n += 1;
            return block;
        }
    };
};
const DtPropIter = struct {
    dt_offset: usize,
    address_cells: u32,
    size_cells: u32,
    fn next(self: *DtPropIter) ?DtProp {
        if (FdtHeader.dt_struct(self.dt_offset) != FDT.PROP) {
            return null;
        }
        self.dt_offset += 4; // FDT_PROP
        const len = FdtHeader.dt_struct(self.dt_offset);
        self.dt_offset += 4; // length
        const name_offset = FdtHeader.dt_struct(self.dt_offset);
        self.dt_offset += 4; // name_offset
        var raw_value: [*]u8 = FdtHeader.dt_raw_ptr() + dtb_uint(_dtb.*.off_dt_struct) + self.dt_offset;
        self.dt_offset += len; // value
        self.dt_offset = roundup(self.dt_offset);

        const prop_name = std.mem.span(dtb_name(name_offset));
        return DtProp{
            .name = prop_name,
            .value = parseValue(prop_name, raw_value[0..len], self.address_cells, self.size_cells),
            .raw_value = raw_value[0..len],
            .address_cells = self.address_cells,
            .size_cells = self.size_cells,
        };
    }
    fn parseValue(prop_name: [:0]const u8, raw_value: []const u8, address_cells: u32, size_cells: u32) DtProp.Value {
        const property_type_map = [_]struct { n: []const u8, t: DtProp.ValueType }{
            .{ .n = "#address-cells", .t = .u32 },
            .{ .n = "#interrupt-cells", .t = .u32 },
            .{ .n = "#size-cells", .t = .u32 },
            // bank-width = ?
            .{ .n = "bootargs", .t = .string },
            // bus-range = ?
            // clock-frequency = or
            .{ .n = "compatible", .t = .stringlist },
            .{ .n = "cpu", .t = .phandle },
            .{ .n = "device_type", .t = .string },
            // dma-coherent = ?
            .{ .n = "interrupt-controller", .t = .empty },
            // interrupt-map = []
            // 1 interrupt-map-mask = []
            .{ .n = "interrupt-parent", .t = .phandle },
            // 10 interrupts = []
            // 2 interrupts-extended = []
            // 1 linux,pci-domain = u32?
            .{ .n = "mmu-type", .t = .string },
            .{ .n = "model", .t = .string },
            // offset = u32?
            .{ .n = "phandle", .t = .phandle },
            // ranges = []
            .{ .n = "reg", .t = .reg },
            // 2 regmap = u32?
            .{ .n = "riscv,isa", .t = .string },
            // 1 riscv,ndev = u32?
            .{ .n = "status", .t = .string },
            .{ .n = "stdin-path", .t = .string },
            .{ .n = "stdout-path", .t = .string },
            // 1 timebase-frequency = or
            // 2 value = u32?
        };
        var property_type: DtProp.ValueType = .unknown;
        for (property_type_map) |nt| {
            if (std.mem.eql(u8, nt.n, prop_name)) {
                property_type = nt.t;
                break;
            }
        }

        switch (property_type) {
            .u32 => return DtProp.Value{ .u32 = be_int(u32, raw_value) },
            .u64 => return DtProp.Value{ .u64 = be_int(u64, raw_value) },
            .reg => return DtProp.Value{ .reg = DtProp.Reg{
                .prop_value = raw_value,
                .address_cells = address_cells,
                .size_cells = size_cells,
                .pair_n = 0,
            } },
            .string => return DtProp.Value{ .string = @ptrCast([*:0]const u8, raw_value.ptr) },
            .stringlist => return DtProp.Value{ .stringlist = std.mem.split(u8, raw_value, "\x00") },
            .empty => return .empty,
            .phandle => return DtProp.Value{ .phandle = be_int(u32, raw_value) },
            .unknown => return .unknown,
        }
    }
};
