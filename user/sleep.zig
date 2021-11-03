const std = @import("std");
const os = @import("user.zig");

export fn main(argc: i32, argv: [*][*:0]const u8) i32 {
    if (argc != 2) {
        os.fprintf(2, "error: requires exactly one argument\n");
        os.exit(1);
    }
    const sleep_time = std.fmt.parseInt(i32, std.mem.span(argv[1]), 10) catch {
        os.fprintf(2, "error: must pass in a valid integer\n");
        os.exit(1);
    };
    _ = os.sleep(sleep_time);
    os.exit(0);
}
