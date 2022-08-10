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
    walk_device_tree_iter(0, DtNodeIter{ .dt_offset = 0 });
}
fn walk_device_tree_iter(level: u32, iter_arg: DtNodeIter) void {
    var iter = iter_arg;
    while (iter.next()) |node| {
        print_level_indent(level);
        printf("Node Name: %s\n", node.name.ptr);
        var props = node.properties;
        while (props.next()) |prop| {
            print_level_indent(level + 1);
            print_property(prop.name, prop.value);
        }
        walk_device_tree_iter(level + 1, node.children);
    }
}
fn print_property(name: []u8, value: []u8) void {
    printf("Property (%s) =", name.ptr);
    for (value) |val| {
        printf(" %x", @intCast(u32, val));
    }
    printf("\n");
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
    fn next(self: *DtNodeIter) ?DtNode {
        var node: DtNode = undefined;
        if (FdtHeader.dt_struct(self.dt_offset) != FDT.BEGIN_NODE) {
            return null;
        }
        self.dt_offset += 4; // FDT_BEGIN_NODE
        node.name = std.mem.span(@ptrCast([*:0]u8, FdtHeader.dt_raw_ptr()) + dtb_uint(_dtb.*.off_dt_struct) + self.dt_offset);
        self.dt_offset += node.name.len + 1; // name
        self.dt_offset = roundup(self.dt_offset);

        node.properties = DtPropIter{ .dt_offset = self.dt_offset };

        // parse properties
        while (FdtHeader.dt_struct(self.dt_offset) == FDT.PROP) {
            self.dt_offset += 4; // FDT_PROP
            const len = FdtHeader.dt_struct(self.dt_offset);
            self.dt_offset += 4; // length
            //ignore name_offset
            self.dt_offset += 4; // name_offset
            self.dt_offset += len; // value
            self.dt_offset = roundup(self.dt_offset);
        }
        node.children = DtNodeIter{ .dt_offset = self.dt_offset };
        var children = node.children;
        while (children.next() != null) {}
        self.dt_offset = children.dt_offset; // children
        self.dt_offset += 4; // FDT_END_NODE
        return node;
    }
};

const DtProp = struct {
    name: [:0]u8,
    value: []u8,
};
const DtPropIter = struct {
    dt_offset: usize,
    fn next(self: *DtPropIter) ?DtProp {
        if (FdtHeader.dt_struct(self.dt_offset) != FDT.PROP) {
            return null;
        }
        self.dt_offset += 4; // FDT_PROP
        const len = FdtHeader.dt_struct(self.dt_offset);
        self.dt_offset += 4; // length
        const name_offset = FdtHeader.dt_struct(self.dt_offset);
        self.dt_offset += 4; // name_offset
        var value_raw: [*]u8 = FdtHeader.dt_raw_ptr() + dtb_uint(_dtb.*.off_dt_struct) + self.dt_offset;
        self.dt_offset += len; // value
        self.dt_offset = roundup(self.dt_offset);
        return DtProp{
            .name = std.mem.span(dtb_name(name_offset)),
            .value = value_raw[0..len],
        };
    }
};
