const std = @import("std");
const os = @import("user.zig");

export fn main(argc: i32, argv: [*][*:0]const u8) i32 {
    if (argc != 3) {
        os.fprintf(2, "error: requires exactly two arguments\n");
        os.exit(1);
    }
    const path = std.mem.spanZ(argv[1]);
    const match = std.mem.spanZ(argv[2]);

    // hope for paths shorter than 512 characters
    var prefix: [511:0]u8 = undefined;

    find(&prefix, 0, path, match);
    os.exit(0);
}
fn find(prefix: *[511:0]u8, prefix_len: usize, path: [:0]const u8, match: [:0]const u8) void {
    const new_prefix_len = appendPath(prefix, prefix_len, path);
    if (std.cstr.cmp(path, match) == 0) {
        os.printf("%s\n", prefix);
    }
    const fd = os.open(prefix, 0) catch {
        os.fprintf(2, "error: failed to open path: %s\n", path.ptr);
        os.exit(1);
    };
    defer _ = os.close(fd);
    const st = os.fstat(fd) catch {
        os.fprintf(2, "error: failed to stat path: %s\n", path.ptr);
        os.exit(1);
    };
    switch (st.type) {
        .Dir => {
            var de: os.dirent = undefined;
            const sz = @sizeOf(os.dirent);
            while (os.read(fd, &de, sz) == sz) {
                if (de.inum == 0) {
                    continue;
                }
                var p: [os.DIRSIZ:0]u8 = undefined;
                std.mem.copy(u8, &p, &de.name);
                if (std.cstr.cmp(&p, ".") == 0 or std.cstr.cmp(&p, "..") == 0) {
                    continue;
                }
                find(prefix, new_prefix_len, std.mem.spanZ(&p), match);
            }
        },
        else => {},
    }
}

// appends /path to prefix and returns the new prefix_len
fn appendPath(prefix: *[511:0]u8, prefix_len: usize, path: [:0]const u8) usize {
    var new_prefix_len = prefix_len;
    if (prefix_len != 0) {
        prefix[prefix_len] = '/';
        new_prefix_len += 1;
    }
    std.mem.copy(u8, prefix[new_prefix_len..], path);
    new_prefix_len += path.len;
    prefix[new_prefix_len] = 0;
    return new_prefix_len;
}
