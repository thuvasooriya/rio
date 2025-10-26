// formatting utilities for size and time
// zero dependencies - foundation layer

const std = @import("std");

// format byte size in human-readable units (B, KB, MB, GB)
pub fn format_size(allocator: std.mem.Allocator, size: u64) ![]const u8 {
    if (size >= 1024 * 1024 * 1024) {
        const gb = @as(f64, @floatFromInt(size)) / (1024.0 * 1024.0 * 1024.0);
        return std.fmt.allocPrint(allocator, "{d:.2} GB", .{gb});
    } else if (size >= 1024 * 1024) {
        const mb = @as(f64, @floatFromInt(size)) / (1024.0 * 1024.0);
        return std.fmt.allocPrint(allocator, "{d:.2} MB", .{mb});
    } else if (size >= 1024) {
        const kb = @as(f64, @floatFromInt(size)) / 1024.0;
        return std.fmt.allocPrint(allocator, "{d:.2} KB", .{kb});
    } else {
        return std.fmt.allocPrint(allocator, "{d} bytes", .{size});
    }
}

// print byte size directly to writer with prefix
pub fn print_size(writer: anytype, prefix: []const u8, size: u64) !void {
    try writer.print("{s}", .{prefix});
    if (size >= 1024 * 1024 * 1024) {
        const gb = @as(f64, @floatFromInt(size)) / (1024.0 * 1024.0 * 1024.0);
        try writer.print("{d:.2} GB\n", .{gb});
    } else if (size >= 1024 * 1024) {
        const mb = @as(f64, @floatFromInt(size)) / (1024.0 * 1024.0);
        try writer.print("{d:.2} MB\n", .{mb});
    } else if (size >= 1024) {
        const kb = @as(f64, @floatFromInt(size)) / 1024.0;
        try writer.print("{d:.2} KB\n", .{kb});
    } else {
        try writer.print("{d} bytes\n", .{size});
    }
}

// format time duration in human-readable units (ns, μs, ms, s)
pub fn format_time(allocator: std.mem.Allocator, nanoseconds: u64) ![]const u8 {
    if (nanoseconds >= 1_000_000_000) {
        const seconds = @as(f64, @floatFromInt(nanoseconds)) / 1_000_000_000.0;
        return std.fmt.allocPrint(allocator, "{d:.3} s", .{seconds});
    } else if (nanoseconds >= 1_000_000) {
        const milliseconds = @as(f64, @floatFromInt(nanoseconds)) / 1_000_000.0;
        return std.fmt.allocPrint(allocator, "{d:.3} ms", .{milliseconds});
    } else if (nanoseconds >= 1_000) {
        const microseconds = @as(f64, @floatFromInt(nanoseconds)) / 1_000.0;
        return std.fmt.allocPrint(allocator, "{d:.3} μs", .{microseconds});
    } else {
        return std.fmt.allocPrint(allocator, "{d} ns", .{nanoseconds});
    }
}

test "format size" {
    const allocator = std.testing.allocator;

    const str1 = try format_size(allocator, 1024);
    defer allocator.free(str1);
    try std.testing.expect(std.mem.indexOf(u8, str1, "KB") != null);

    const str2 = try format_size(allocator, 1024 * 1024);
    defer allocator.free(str2);
    try std.testing.expect(std.mem.indexOf(u8, str2, "MB") != null);

    const str3 = try format_size(allocator, 1024 * 1024 * 1024);
    defer allocator.free(str3);
    try std.testing.expect(std.mem.indexOf(u8, str3, "GB") != null);
}

test "format time" {
    const allocator = std.testing.allocator;

    const str1 = try format_time(allocator, 1_000);
    defer allocator.free(str1);
    try std.testing.expect(std.mem.indexOf(u8, str1, "μs") != null);

    const str2 = try format_time(allocator, 1_000_000);
    defer allocator.free(str2);
    try std.testing.expect(std.mem.indexOf(u8, str2, "ms") != null);

    const str3 = try format_time(allocator, 1_000_000_000);
    defer allocator.free(str3);
    try std.testing.expect(std.mem.indexOf(u8, str3, "s") != null);
}
