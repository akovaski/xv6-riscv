const std = @import("std");
const os = @import("user.zig");

export fn main() i32 {
    var p: [2]i32 = undefined;
    os.pipe(&p) catch {
        os.fprintf(2, "error: pipe creation failed\n");
        os.exit(1);
    };
    const child = os.fork() catch {
        os.fprintf(2, "error: fork failed\n");
        os.exit(1);
    };
    const pid = os.getpid();
    if (child != null) {
        send_signal(p[1]);
        _ = os.wait(0);
        receive_signal(p[0]);
        os.printf("%d: received pong\n", pid);
    } else {
        receive_signal(p[0]);
        os.printf("%d: received ping\n", pid);
        send_signal(p[1]);
    }
    os.exit(0);
}

fn receive_signal(p_r: i32) void {
    var data: u8 = undefined;
    const n = os.read(p_r, &data, 1);
    if (n != 1) {
        os.fprintf(2, "error (%d): invalid result from reading from pipe\n", n);
        os.exit(1);
    }
}
fn send_signal(p_w: i32) void {
    var data: u8 = 0;
    const n = os.write(p_w, &data, 1);
    if (n != 1) {
        os.fprintf(2, "error (%d): invalid result from writing to pipe\n", n);
        os.exit(1);
    }
}
