const std = @import("std");
const os = @import("user.zig");

export fn main() i32 {
    var i: u8 = 2;
    var p: [2]i32 = undefined;
    os.pipe(&p) catch {
        os.fprintf(2, "error: pipe creation failed\n");
        os.exit(1);
    };
    var p_w = create_right_processor(null, p[1]);
    while (i < 36) {
        const data: u8 = i;
        const n = os.write(p_w, &data, 1);
        if (n != 1) {
            os.fprintf(2, "error (%d): main loop invalid result from writing to pipe\n", n);
            os.exit(1);
        }
        i += 1;
    }
    _ = os.close(p_w);
    var data: u8 = undefined;
    const n = os.read(p[0], &data, 1);
    if (n != 1) {
        os.fprintf(2, "error (%d): main result invalid result from reading from pipe\n", n);
        os.exit(1);
    }

    os.printf("main completed as expected :) \n");
    os.exit(0);
}

fn create_right_processor(p_in: ?i32, p_last_close: i32) i32 {
    var p: [2]i32 = undefined;
    os.pipe(&p) catch {
        os.fprintf(2, "error: pipe creation failed\n");
        os.exit(1);
    };
    const child = os.fork() catch {
        os.fprintf(2, "error: fork failed\n");
        os.exit(1);
    };
    if (child == null) {
        if (p_in) |some_p_in| {
            _ = os.close(some_p_in);
        }
        _ = os.close(p[1]);
        var id: ?u8 = null;
        var p_w: ?i32 = null;
        while (true) {
            var data: u8 = undefined;
            const n = os.read(p[0], &data, 1);
            if (n == 0) {
                // pipe closed
                if (p_w == null) {
                    data = 0;
                    _ = os.write(p_last_close, &data, 1);
                }
                os.exit(0);
            } else if (n != 1) {
                os.fprintf(2, "error (%d): child read invalid result from reading from pipe\n", n);
                os.exit(1);
            }
            if (id) |check| {
                if (data % check != 0) {
                    if (p_w == null) {
                        p_w = create_right_processor(p[0], p_last_close);
                        _ = os.close(p_last_close);
                    }
                    const n_w = os.write(p_w.?, &data, 1);
                    if (n_w != 1) {
                        os.fprintf(2, "error (%d): invalid result from writing to pipe\n", n_w);
                        os.exit(1);
                    }
                }
            } else {
                id = data;
                os.printf("prime %d\n", data);
            }
        }
    } else {
        _ = os.close(p[0]);
        return p[1];
    }
}
