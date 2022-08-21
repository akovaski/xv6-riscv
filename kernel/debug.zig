const std = @import("std");
const kernel = @import("kernel.zig");
const c = kernel.c;
const lock = kernel.lock;

extern var pr: extern struct {
    lock: lock.SpinLock,
    locking: c_int,

    const Self = @This();
    pub fn acquire(self: *Self) void {
        if (self.locking != 0) {
            self.lock.acquire();
        }
    }
    pub fn release(self: *Self) void {
        if (self.locking != 0) {
            self.lock.release();
        }
    }
};

const stderr = StdErr.writer();
const StdErr = struct {
    pub const Error = error{StdErrWrite};
    pub const Writer = std.io.Writer(void, Error, write);
    pub fn writer() Writer {
        return .{ .context = {} };
    }
    pub fn write(_: void, bytes: []const u8) Error!usize {
        for (bytes) |b| {
            c.consputc(b);
        }
        return bytes.len;
    }
};

/// Print to stderr, unbuffered, and silently returning on failure. Intended
/// for use in "printf debugging." Use `std.log` functions for proper logging.
pub fn print(comptime fmt: []const u8, args: anytype) void {
    pr.acquire();
    defer pr.release();
    nosuspend stderr.print(fmt, args) catch return;
}
