const c = @cImport({
    @cInclude("kernel/types.h");
    @cInclude("kernel/stat.h");
    @cInclude("user/user.h");
});

const std = @import("std");
extern fn sleep(i32) i32;
export fn main(argc: i32, argv: [*][*:0]const u8) i32 {
    if (argc != 2) {
        c.fprintf(2, "error: requires exactly one argument\n");
        c.exit(1);
    }
    const sleep_time = std.fmt.parseInt(i32, std.mem.span(argv[1]), 10) catch {
        c.fprintf(2, "error: must pass in a valid integer\n");
        c.exit(1);
    };
    _ = sleep(sleep_time);
    c.exit(0);
}
