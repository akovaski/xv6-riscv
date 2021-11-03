const c = @cImport({
    @cInclude("kernel/types.h");
    @cInclude("kernel/stat.h");
    @cInclude("user/user.h");
});

const std = @import("std");
const os = @import("user.zig");

export fn main() i32 {
    os.printf("Starting my_fork\n");
    const child = os.fork() catch {
        os.fprintf(2, "error: forking failed\n");
        os.exit(1);
    };
    if (child) |pid| {
        os.printf("parent: child=%d\n", pid);
        const wait_pid = os.wait(null);
        os.printf("child %d is done\n", wait_pid);
        os.exit(0);
    } else {
        os.printf("child: exiting\n");
        os.exit(0);
    }
}
