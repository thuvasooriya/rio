const std = @import("std");

test "import all modules" {
    _ = @import("bench/metrics.zig");
    _ = @import("bench/pattern.zig");
    _ = @import("bench/runner.zig");
    _ = @import("io/engine.zig");
    _ = @import("io/platform/linux.zig");
    _ = @import("io/platform/windows.zig");
    _ = @import("io/platform/darwin.zig");
    _ = @import("cli/args.zig");
    _ = @import("cli/reporter.zig");
    _ = @import("core/stats.zig");
    _ = @import("core/types.zig");
    _ = @import("core/format.zig");
}
