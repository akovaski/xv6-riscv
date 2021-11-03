const c = @cImport({
    @cInclude("kernel/types.h");
    @cInclude("kernel/stat.h");
    @cInclude("user/user.h");
});

const std = @import("std");
const os = @import("user.zig");

// I would like to have this type be !noreturn,
// but the zig compiler runs away if I do that
// https://github.com/ziglang/zig/issues/3461
fn my_fork() !void {
    os.printf("Starting my_fork\n");
    const pid = os.fork();
    switch (pid) {
        1...std.math.maxInt(i32) => {
            os.printf("parent: child=%d\n", pid);
            const wait_pid = os.wait(null);
            os.printf("child %d is done\n", wait_pid);
            os.exit(0);
        },
        0 => {
            os.printf("child: exiting\n");
            os.exit(0);
        },
        else => return error.InvalidForkPid,
    }
}

export fn main() i32 {
    my_fork() catch |err| {
        const error_name = switch (err) {
            error.InvalidForkPid => "Fork returned with invalid PID",
        };
        os.fprintf(2, "my_fork failed with error: %s\n", error_name);
        os.exit(1);
    };
    os.fprintf(2, "my_fork failed with a double surprise\n");
    c.exit(1);
}
