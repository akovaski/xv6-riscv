const std = @import("std");
const os = @import("user.zig");

export fn main(argc: i32, argv: [*][*:0]const u8) i32 {
    if (argc < 3) {
        os.fprintf(2, "error: requires at least two arguments: trace-mask and command\n");
        os.exit(1);
    }

    const trace_mask = std.fmt.parseInt(i32, std.mem.span(argv[1]), 10) catch {
        os.fprintf(2, "error: first argument must be a valid integer\n");
        os.exit(1);
    };
    os.fprintf(2, "trace mask %d\n", trace_mask);

    const uargc: usize = @intCast(usize, argc);
    var new_argv: [os.MAXARG:null]?[*:0]const u8 = undefined;
    var i: usize = 0;
    while (i + 2 < uargc) {
        new_argv[i] = argv[i + 2];
        i += 1;
    }
    new_argv[i] = null;

    os.trace(trace_mask) catch {
        os.fprintf(2, "trace syscall failed, mask: %d\n", trace_mask);
        os.exit(1);
    };
    const ret: i32 = os.exec(argv[2], &new_argv);
    os.fprintf(2, "calling %s failed: %d\n", new_argv[0], ret);
    os.exit(1);
}
