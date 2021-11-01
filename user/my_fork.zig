const c = @cImport({
    @cInclude("kernel/types.h");
    @cInclude("kernel/stat.h");
    @cInclude("user/user.h");
});

const std = @import("std");

// I would like to have this type be !noreturn,
// but the zig compiler runs away if I do that
fn my_fork() !void {
    c.printf("Starting my_fork\n");
    const pid = c.fork();
    switch (pid) {
        1...std.math.maxInt(i32) => {
            c.printf("parent: child=%d\n", pid);
            const wait_pid = c.wait(null);
            c.printf("child %d is done\n", wait_pid);
            c.exit(0);
        },
        0 => {
            c.printf("child: exiting\n");
            c.exit(0);
        },
        else => return error.InvalidForkPid,
    }
}

export fn main() i32 {
    my_fork() catch |err| {
        const error_name = switch (err) {
            error.InvalidForkPid => "Fork returned with invalid PID",
        };
        c.fprintf(2, "my_fork failed with error: %s\n", error_name);
        c.exit(1);
    };
    c.fprintf(2, "my_fork failed with a double surprise\n");
    c.exit(1);
}
