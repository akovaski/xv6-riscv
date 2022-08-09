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

export fn dtb_uint(x: u32) u32 {
    return (((x) & 0xff000000) >> 24) |
        (((x) & 0x00ff0000) >> 8) |
        (((x) & 0x0000ff00) << 8) |
        (((x) & 0x000000ff) << 24);
}

export fn str_len(s: [*:0]u8) u32 {
  var i: u32 = 0;
  while (s[i] != 0) {
    i += 1;
  }
  return i;
}

export fn roundup(x: usize) usize {
    var rem: usize = x % 4;
    return if (rem == 0) x else x - rem + 4;
}
export fn dtb_name(arg_name_offset: u32) [*c]u8 {
    var name_offset = arg_name_offset;
    return FdtHeader.dt_string() + name_offset;
}
export fn print_level_indent(level: u32) void {
    var i: u32 = 0;
    while (i < level) : (i += 1) {
        printf("  ");
    }
}
export fn print_prop_value(dt_offset: usize, len: u32) void {
    var start: [*c]u8 = FdtHeader.dt_raw_ptr() + dtb_uint(_dtb.*.off_dt_struct) + dt_offset;
    var i: u32 = 0;
    while (i < len) : (i += 1) {
        if (i != 0) {
            printf(" ");
        }
        const val: u32 = start[i];
        printf("%x", val);
    }
}

export fn walk_device_tree() void {
    printf("_dtb: %p\n", _dtb);
    printf("magic: %p\n", dtb_uint(_dtb.magic));
    printf("struct: %p\n", dtb_uint(_dtb.off_dt_struct));
    _ = walk_device_tree_inner(0, 0) catch {
        printf("error walking tree\n");
    };
}
fn walk_device_tree_inner(level: u32, dt_offset_rough: usize) error{UnknownNode}!usize {
    var dt_offset = dt_offset_rough;
    while (true) {
        dt_offset = roundup(dt_offset);
        var entry: u32 = FdtHeader.dt_struct(dt_offset);
        dt_offset += 4;
        print_level_indent(level);
        switch (entry) {
            0x1 => {
                // const name: []u8 = std.mem.span(@ptrCast([*:0]u8, FdtHeader.dt_raw_ptr()) + dt_offset);
                const name: [*:0]u8 = @ptrCast([*:0]u8, FdtHeader.dt_raw_ptr()) + dtb_uint(_dtb.*.off_dt_struct) + dt_offset;
                const name_len: u32 = str_len(name);
                printf("> FDT_BEGIN_NODE, name(%p, %d): \"%s\"\n", name, name_len, name);
                dt_offset += name_len + 1;
                dt_offset = try walk_device_tree_inner(level + 1, dt_offset);
                printf("> FDT_END_NODE\n");
            },
            0x2 => {
                return dt_offset;
            },
            0x3 => {
                const len = FdtHeader.dt_struct(dt_offset);
                dt_offset += 4;
                const name_offset = FdtHeader.dt_struct(dt_offset);
                dt_offset += 4;
                printf("> FDT_PROP, len: %d, name(%d): %s, value: ", len, name_offset, dtb_name(name_offset));
                print_prop_value(dt_offset, len);
                printf("\n");
                dt_offset += len;
            },
            0x9 => {
                printf("> FDT_END\n");
                return dt_offset;
            },
            else => {
                printf("unknown node %d\n", entry);
                return error.UnknownNode;
            },
        }
    }
}