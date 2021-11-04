const c = @cImport({
    @cInclude("kernel/types.h");
    @cInclude("kernel/stat.h");
    @cInclude("user/user.h");
});

pub const printf = c.printf;
pub const fprintf = c.fprintf;
pub const exit = c.exit;
pub const read = c.read;
pub const write = c.write;
pub const close = c.close;
pub const wait = c.wait;
pub const getpid = c.getpid;

// parent process: return child's PID
// child process: return null
pub fn fork() !?i32 {
    const result = c.fork();
    if (result < 0) {
        return error.ForkFailed;
    } else if (result == 0) {
        return null;
    } else {
        return result;
    }
}
pub fn pipe(p: *[2]i32) !void {
    const result = c.pipe(p);
    if (result != 0) {
        return error.PipeCreationFailed;
    }
}
pub extern fn sleep(i32) i32;
