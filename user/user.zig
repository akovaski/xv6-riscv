const c = @cImport({
    @cInclude("kernel/types.h");
    @cInclude("kernel/stat.h");
    @cInclude("user/user.h");
    @cInclude("kernel/fs.h");
});

pub const printf = c.printf;
pub const fprintf = c.fprintf;
pub const exit = c.exit;
pub const read = c.read;
pub const write = c.write;
pub const close = c.close;
pub const wait = c.wait;
pub const getpid = c.getpid;

pub fn open(path: [*:0]const u8, flags: i32) !i32 {
    const fd = c.open(path, flags);
    if (fd < 0) {
        return error.FileOpen;
    }
    return fd;
}

pub const DIRSIZ = c.DIRSIZ;
pub const dirent = c.struct_dirent;
pub const Stat = struct {
    dev: i32,
    ino: u32,
    type: FileType,
    nlink: i16,
    size: u64,
};
pub const FileType = enum {
    Dir,
    File,
    Device,
};
pub fn fstat(fd: i32) !Stat {
    var st: c.struct_stat = undefined;
    if (c.fstat(fd, &st) < 0) {
        return error.FStatError;
    }
    const file_type: FileType = switch (st.type) {
        1 => .Dir,
        2 => .File,
        3 => .Device,
        else => unreachable,
    };
    return Stat{
        .dev = st.dev,
        .ino = st.ino,
        .type = file_type,
        .nlink = st.nlink,
        .size = st.size,
    };
}

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
