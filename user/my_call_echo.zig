const c = @cImport({
    @cInclude("kernel/types.h");
    @cInclude("kernel/stat.h");
    @cInclude("user/user.h");
});

const std = @import("std");

extern fn exec([*:0]const u8, [*:null]const ?[*:0]const u8) i32;
export fn main() i32 {
    const argv = [_:null]?[*:0]const u8{
        "echo",
        "hello",
        "world",
    };
    const command = "echo";
    const ret: i32 = exec(command, &argv);
    c.fprintf(2, "my_call_echo failed: %d\n", ret);
    c.exit(1);
}
