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

// get color based on throughput performance
fn getThroughputColor(gbps: f64) Color {
    if (gbps >= 5.0) return .green;
    if (gbps >= 1.0) return .yellow;
    return .red;
}

// format throughput value
fn formatThroughput(gbps: f64) []const u8 {
    if (gbps >= 1.0) return "Gbps";
    return "Mbps";
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

pub fn printText(self: *Reporter, res: *const Metrics.BenchmarkResult) !void {
    const gbps = res.throughput.toGBps();
    const color = getThroughputColor(gbps);

    // format throughput value
    var throughput_value: f64 = undefined;
    var throughput_unit: []const u8 = undefined;

    if (gbps >= 1.0) {
        throughput_value = gbps;
        throughput_unit = "Gbps";
    } else {
        throughput_value = res.throughput.toMBps();
        throughput_unit = "Mbps";
    }

    // format IOPS
    var iops_buffer: [32]u8 = undefined;
    const iops_str = try formatIOPS(res.iops.operations_per_second, &iops_buffer);

    // print checkmark and test name
    try self.terminal.writeColor(.green, "✓");
    try self.terminal.write(" ");
    try self.terminal.writeColor(.bold, res.test_name);

    // pad to align results
    const name_len = res.test_name.len;
    const target_width: usize = 20;
    if (name_len < target_width) {
        const padding = target_width - name_len;
        var i: usize = 0;
        while (i < padding) : (i += 1) {
            try self.terminal.write(" ");
        }
    }

    // print throughput
    try self.terminal.printColor(color, "{d:.2} {s}", .{ throughput_value, throughput_unit });
    try self.terminal.write("  |  ");

    // print IOPS
    try self.terminal.write(iops_str);
    try self.terminal.write(" IOPS");
    try self.terminal.write("  |  ");

    // print avg latency
    try self.terminal.printColor(.dim, "{d:.2}μs avg", .{res.latency.avg_us});
    try self.terminal.write("\n");
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

pub fn printHeader(self: *Reporter, config: struct {
    target_path: []const u8,
    file_size_mb: u64,
    block_size_kb: u64,
    duration_s: u64,
    mode: []const u8,
}) !void {
    if (self.use_json) return;

    var buf: [128]u8 = undefined;
    const version_str = try std.fmt.bufPrint(&buf, "rio v{s}", .{version.version});
    try self.terminal.writeColor(.bold, version_str);
    try self.terminal.write(" - Disk Benchmark Tool\n\n");

    try self.terminal.write("Target: ");
    try self.terminal.writeColor(.cyan, config.target_path);
    try self.terminal.write("\n");

    try self.terminal.write("Size: ");
    try self.terminal.printColor(.bold, "{d} MB", .{config.file_size_mb});
    try self.terminal.write("  |  Block: ");
    try self.terminal.printColor(.bold, "{d} KB", .{config.block_size_kb});
    try self.terminal.write("  |  Duration: ");
    try self.terminal.printColor(.bold, "{d}s", .{config.duration_s});
    try self.terminal.write("  |  Mode: ");
    try self.terminal.writeColor(.bold, config.mode);
    try self.terminal.write("\n\n");
}

pub fn printFooter(self: *Reporter) !void {
    if (self.use_json) return;

    try self.terminal.write("\n");
    try self.terminal.writeColor(.green, "Benchmark complete!");
    try self.terminal.write("\n");
}

// print results in a box that grows with each result
// returns the number of lines printed
pub fn printResultsBox(self: *Reporter, results: []const Metrics.BenchmarkResult) !usize {
    if (self.use_json) return 0;
    if (results.len == 0) return 0;

    // build result lines
    var lines = std.ArrayList([]u8){};
    defer {
        for (lines.items) |line| {
            self.allocator.free(line);
        }
        lines.deinit(self.allocator);
    }

    for (results) |*res| {
        const gbps = res.throughput.toGBps();

        // format throughput value
        var throughput_value: f64 = undefined;
        var throughput_unit: []const u8 = undefined;

        if (gbps >= 1.0) {
            throughput_value = gbps;
            throughput_unit = "Gbps";
        } else {
            throughput_value = res.throughput.toMBps();
            throughput_unit = "Mbps";
        }

        // format IOPS
        var iops_buffer: [32]u8 = undefined;
        const iops_str = try formatIOPS(res.iops.operations_per_second, &iops_buffer);

        // build line without colors (we'll add colors during printing)
        const line = try std.fmt.allocPrint(
            self.allocator,
            "  ✓ {s: <18} {d:.2} {s}  |  {s} IOPS  |  {d:.2}μs avg",
            .{ res.test_name, throughput_value, throughput_unit, iops_str, res.latency.avg_us },
        );
        try lines.append(self.allocator, line);
    }

    // draw box
    const top_left = "╭";
    const top_right = "╮";
    const bottom_left = "╰";
    const bottom_right = "╯";
    const horizontal = "─";
    const vertical = "│";

    // find max width
    var max_width: usize = 0;
    for (lines.items) |line| {
        if (line.len > max_width) max_width = line.len;
    }

    var line_count: usize = 0;

    // top border
    try self.terminal.write(top_left);
    var i: usize = 0;
    while (i < max_width + 2) : (i += 1) {
        try self.terminal.write(horizontal);
    }
    try self.terminal.write(top_right);
    try self.terminal.write("\n");
    line_count += 1;

    // content lines
    for (lines.items) |line| {
        try self.terminal.write(vertical);
        try self.terminal.write(line);
        // pad to max width
        const padding = max_width - line.len;
        var j: usize = 0;
        while (j < padding) : (j += 1) {
            try self.terminal.write(" ");
        }
        try self.terminal.write(" ");
        try self.terminal.write(vertical);
        try self.terminal.write("\n");
        line_count += 1;
    }

    // bottom border
    try self.terminal.write(bottom_left);
    i = 0;
    while (i < max_width + 2) : (i += 1) {
        try self.terminal.write(horizontal);
    }
    try self.terminal.write(bottom_right);
    try self.terminal.write("\n");
    line_count += 1;

    return line_count;
}
