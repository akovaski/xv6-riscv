const std = @import("std");
const os = @import("user.zig");

extern fn exec([*:0]const u8, [*:null]const ?[*:0]const u8) i32;
export fn main() i32 {
    const argv = [_:null]?[*:0]const u8{
        "echo",
        "hello",
        "world",
    };
    const command = "echo";
    const ret: i32 = exec(command, &argv);
    os.fprintf(2, "my_call_echo failed: %d\n", ret);
    os.exit(1);
}
