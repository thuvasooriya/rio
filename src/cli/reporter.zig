const std = @import("std");
const Metrics = @import("../bench/metrics.zig");
const Terminal = @import("terminal.zig").Terminal;
const Color = @import("terminal.zig").Color;
const version = @import("../version.zig");

const Reporter = @This();

allocator: std.mem.Allocator,
terminal: Terminal,
use_json: bool,

pub fn init(allocator: std.mem.Allocator, terminal: Terminal, use_json: bool) Reporter {
    return .{
        .allocator = allocator,
        .terminal = terminal,
        .use_json = use_json,
    };
}

pub fn deinit(self: *Reporter) void {
    _ = self;
}

// format IOPS with K/M suffix
pub fn formatIOPS(iops: u64, buffer: []u8) ![]const u8 {
    if (iops >= 1_000_000) {
        return std.fmt.bufPrint(buffer, "{d:.1}M", .{@as(f64, @floatFromInt(iops)) / 1_000_000.0});
    } else if (iops >= 1_000) {
        return std.fmt.bufPrint(buffer, "{d:.0}K", .{@as(f64, @floatFromInt(iops)) / 1_000.0});
    } else {
        return std.fmt.bufPrint(buffer, "{d}", .{iops});
    }
}

pub fn printJson(self: *Reporter, res: *const Metrics.BenchmarkResult) !void {
    try self.terminal.print("  {{\n", .{});
    try self.terminal.print("    \"test_name\": \"{s}\",\n", .{res.test_name});
    try self.terminal.print("    \"throughput_bps\": {d},\n", .{res.throughput.bytes_per_second});
    try self.terminal.print("    \"throughput_mbps\": {d:.2},\n", .{res.throughput.toMBps()});
    try self.terminal.print("    \"iops\": {d},\n", .{res.iops.operations_per_second});
    try self.terminal.print("    \"duration_ms\": {d},\n", .{res.duration_ms});
    try self.terminal.print("    \"latency_us\": {{\n", .{});
    try self.terminal.print("      \"min\": {d},\n", .{res.latency.min_us});
    try self.terminal.print("      \"avg\": {d:.2},\n", .{res.latency.avg_us});
    try self.terminal.print("      \"p95\": {d},\n", .{res.latency.p95_us});
    try self.terminal.print("      \"p99\": {d},\n", .{res.latency.p99_us});
    try self.terminal.print("      \"max\": {d}\n", .{res.latency.max_us});
    try self.terminal.print("    }}\n", .{});
    try self.terminal.print("  }}", .{});
}
