// place imports in comptime to force evaluation
// to ensure variables and functions are exported
comptime {
    _ = @import("device_tree.zig");
}