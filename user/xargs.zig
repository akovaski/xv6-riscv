const std = @import("std");
const os = @import("user.zig");

export fn main(argc: i32, argv: [*][*:0]const u8) i32 {
    if (argc < 2) {
        os.fprintf(2, "error: requires at least one argument\n");
        os.exit(1);
    }

    const uargc: usize = @intCast(usize, argc);
    var new_argv: [os.MAXARG:null]?[*:0]const u8 = undefined;
    var i: usize = 0;
    while (i + 1 < uargc) {
        new_argv[i] = argv[i + 1];
        i += 1;
    }

    var buf: [512:0]u8 = undefined;

    while (true) {
        const last = read_one_line(&buf);

        if (last and buf[0] == 0) {
            // ignore last line if empty
            // for example `echo hello` will output a newline,
            // but xargs will just use 'hello'
            os.exit(0);
        }

        new_argv[i] = &buf;
        new_argv[i + 1] = null;

        const child = os.fork() catch {
            os.fprintf(2, "error: forking failed\n");
            os.exit(1);
        };
        if (child != null) {
            _ = os.wait(null);
        } else {
            _ = os.close(0);
            const ret: i32 = os.exec(argv[1], &new_argv);
            os.fprintf(2, "calling %s failed: %d\n", new_argv[0], ret);
            os.exit(1);
        }

        if (last) {
            os.exit(0);
        }
    }
}

// return boolean is true if reached end of stdin
fn read_one_line(buf: [*]u8) bool {
    var i: usize = 0;
    while (true) {
        var char: u8 = undefined;
        const n = os.read(0, &char, 1);
        if (n < 0) {
            os.fprintf(2, "read error\n");
            os.exit(1);
        }
        if (n == 0) {
            buf[i] = 0;
            return true;
        } else if (char == '\n') {
            buf[i] = 0;
            return false;
        } else {
            buf[i] = char;
        }
        i += 1;
    }
}
