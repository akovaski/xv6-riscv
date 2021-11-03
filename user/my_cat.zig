const c = @cImport({
    @cInclude("kernel/types.h");
    @cInclude("kernel/stat.h");
    @cInclude("user/user.h");
});

const std = @import("std");

export fn main() i32 {
    var buf: [512]u8 = undefined;
    while (true) {
        const n = c.read(0, &buf, @sizeOf(@TypeOf(buf)));
        if (n == 0) {
            c.exit(0);
        } else if (n < 0) {
            c.fprintf(2, "read error\n");
            c.exit(1);
        }
        if (c.write(1, &buf, n) != n) {
            c.fprintf(2, "write error\n");
            c.exit(1);
        }
    }
}
