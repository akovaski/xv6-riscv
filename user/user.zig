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
pub const fork = c.fork;
pub const wait = c.wait;
pub extern fn sleep(i32) i32;
