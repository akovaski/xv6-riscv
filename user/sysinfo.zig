const std = @import("std");
const os = @import("user.zig");

export fn main() i32 {
    const info = os.sysinfo() catch {
        os.fprintf(2, "error: Unable to retrieve sysinfo\n");
        os.exit(1);
    };

    os.printf("SysInfo:\n");
    os.printf("  freemem: %l\n", info.freemem);
    os.printf("  nproc: %d\n", info.nproc);
    os.exit(0);
}
