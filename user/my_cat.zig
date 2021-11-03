const std = @import("std");
const os = @import("user.zig");

export fn main() i32 {
    var buf: [512]u8 = undefined;
    while (true) {
        const n = os.read(0, &buf, @sizeOf(@TypeOf(buf)));
        if (n == 0) {
            os.exit(0);
        } else if (n < 0) {
            os.fprintf(2, "read error\n");
            os.exit(1);
        }
        if (os.write(1, &buf, n) != n) {
            os.fprintf(2, "write error\n");
            os.exit(1);
        }
    }
}
