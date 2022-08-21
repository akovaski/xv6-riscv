// place imports in comptime to force evaluation
// to ensure variables and functions are exported
comptime {
    _ = @import("device_tree.zig");
}
const std = @import("std");
pub const c = @cImport({
    @cInclude("kernel/types.h");
    @cInclude("kernel/riscv.h");
    @cInclude("kernel/defs.h");
});

pub const lock = @import("lock.zig");
pub const debug = @import("debug.zig");

pub const log_level: std.log.Level = .info;
pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // Ignore all non-error logging from sources other than .default
    const scope_prefix = switch (scope) {
        .default => "",
        else => if (@enumToInt(level) <= @enumToInt(std.log.Level.err))
            "(" ++ @tagName(scope) ++ "): "
        else
            return,
    };
    const prefix = "[" ++ level.asText() ++ "] " ++ scope_prefix;

    // Print the message to stderr, silently ignoring any errors
    debug.print(prefix ++ format ++ "\n", args);
}
