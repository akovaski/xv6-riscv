const c_defs = struct {
    pub extern fn acquire(arg_lk: *SpinLock) void;
    pub extern fn release(arg_lk: *SpinLock) void;
    pub extern fn initlock(arg_lk: *SpinLock, arg_name: [*]const u8) void;
    pub extern fn holding(arg_lk: *SpinLock) c_int;
    pub extern fn push_off() void;
    pub extern fn pop_off() void;
};

// Mutual exclusion lock.
pub const SpinLock = extern struct {
    locked: c_uint, // Is the lock held?

    // For debugging:
    name: *u8, // Name of lock.
    cpu: *opaque {}, // The cpu holding the lock.

    pub fn acquire(self: *SpinLock) void {
        c_defs.acquire(self);
    }

    pub fn release(self: *SpinLock) void {
        c_defs.release(self);
    }
};
