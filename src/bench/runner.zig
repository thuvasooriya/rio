const std = @import("std");
const Metrics = @import("metrics.zig");
const IoEngine = @import("../io/engine.zig");
const types = @import("../core/types.zig");
const Pattern = @import("pattern.zig");

const Benchmark = @This();

allocator: std.mem.Allocator,

pub const Config = struct {
    path: []const u8,
    duration_seconds: u32 = 5,
    block_size: usize = 1024 * 1024,
    file_size: u64 = 4 * 1024 * 1024,
    io_mode: types.IOMode = .direct,
    pattern_type: Pattern.PatternType = .random,
    queue_depth: u32 = 1,
    progress_callback: ?*const fn (elapsed_s: f64, total_s: f64, throughput_bps: f64) void = null,
    completion_callback: ?*const fn () void = null,
    verbose: bool = false,
};

pub const IOPattern = enum {
    sequential_read,
    sequential_write,
    random_read,
    random_write,
};

pub fn init(allocator: std.mem.Allocator) Benchmark {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Benchmark) void {
    _ = self;
}

pub fn prepareFile(self: *Benchmark, path: []const u8, size: u64, block_size: usize, verbose: bool) !void {
    if (verbose) {
        std.log.info("Preparing test file: {s} ({d} MB)", .{ path, size / (1024 * 1024) });
    }

    var engine = try IoEngine.init(self.allocator, .{
        .path = path,
        .mode = .buffered,
        .file_size = size,
        .block_size = block_size,
        .pattern = .sequential,
    });
    defer engine.deinit();

    const buffer = try Pattern.generatePattern(
        self.allocator,
        .random,
        block_size,
        0xDEADBEEF,
    );
    defer Pattern.freePattern(self.allocator, buffer);

    try engine.fastFill(size, buffer);

    if (verbose) {
        std.log.info("Test file prepared successfully", .{});
    }
}

pub fn run(self: *Benchmark, name: []const u8, cfg: Config, io_pattern: IOPattern) !Metrics.BenchmarkResult {
    if (cfg.verbose) {
        std.log.info("Starting benchmark: {s}", .{name});
        std.log.info("  Pattern: {s}", .{@tagName(io_pattern)});
        std.log.info("  Block size: {d} KB", .{cfg.block_size / 1024});
        std.log.info("  Duration: {d}s", .{cfg.duration_seconds});
        std.log.info("  IO Mode: {s}", .{@tagName(cfg.io_mode)});
    }

    const result = switch (io_pattern) {
        .sequential_read => try self.runSequentialRead(cfg),
        .sequential_write => try self.runSequentialWrite(cfg),
        .random_read => try self.runRandomRead(cfg),
        .random_write => try self.runRandomWrite(cfg),
    };

    return .{
        .test_name = name,
        .throughput = result.throughput,
        .iops = result.iops,
        .latency = result.latency,
        .duration_ms = result.duration_ms,
    };
}

fn runSequentialRead(self: *Benchmark, cfg: Config) !BenchmarkMetrics {
    var engine = try IoEngine.init(self.allocator, .{
        .path = cfg.path,
        .mode = cfg.io_mode,
        .file_size = cfg.file_size,
        .block_size = cfg.block_size,
        .pattern = .sequential,
    });
    defer engine.deinit();

    engine.dropCache();

    const buffer = try Pattern.generatePattern(
        self.allocator,
        .zero,
        cfg.block_size,
        0,
    );
    defer Pattern.freePattern(self.allocator, buffer);

    var latency = Metrics.Latency.init(self.allocator);
    errdefer latency.deinit();

    var total_bytes: u64 = 0;
    var operations: u64 = 0;
    var offset: u64 = 0;

    const start_time = std.time.nanoTimestamp();
    const duration_ns = @as(i128, cfg.duration_seconds) * std.time.ns_per_s;
    var last_progress_time = start_time;

    while (true) {
        const op_start = std.time.nanoTimestamp();
        if (op_start - start_time >= duration_ns) break;

        const bytes_read = try engine.read(offset, buffer);
        const op_end = std.time.nanoTimestamp();

        const latency_ns = op_end - op_start;
        const latency_us = @as(u64, @intCast(@divFloor(latency_ns, std.time.ns_per_us)));
        try latency.record(latency_us);

        total_bytes += bytes_read;
        operations += 1;

        offset += cfg.block_size;
        if (offset >= cfg.file_size) {
            offset = 0;
        }

        // progress callback every 100ms
        if (cfg.progress_callback) |callback| {
            const progress_interval_ns = 100 * std.time.ns_per_ms;
            if (op_end - last_progress_time >= progress_interval_ns) {
                const elapsed_ns_f = @as(f64, @floatFromInt(op_end - start_time));
                const elapsed_s = elapsed_ns_f / @as(f64, std.time.ns_per_s);
                const total_s = @as(f64, @floatFromInt(cfg.duration_seconds));
                const throughput_bps = @as(f64, @floatFromInt(total_bytes)) / elapsed_s;
                callback(elapsed_s, total_s, throughput_bps);
                last_progress_time = op_end;
            }
        }
    }

    const end_time = std.time.nanoTimestamp();
    const elapsed_ns = end_time - start_time;
    const elapsed_ms = @as(u64, @intCast(@divFloor(elapsed_ns, std.time.ns_per_ms)));

    if (cfg.completion_callback) |callback| {
        callback();
    }

    try latency.calculate();

    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_s);
    const throughput_bps = @as(f64, @floatFromInt(total_bytes)) / elapsed_s;

    return .{
        .throughput = .{ .bytes_per_second = throughput_bps },
        .iops = .{ .operations_per_second = operations / cfg.duration_seconds },
        .latency = latency,
        .duration_ms = elapsed_ms,
    };
}

fn runSequentialWrite(self: *Benchmark, cfg: Config) !BenchmarkMetrics {
    var engine = try IoEngine.init(self.allocator, .{
        .path = cfg.path,
        .mode = cfg.io_mode,
        .file_size = cfg.file_size,
        .block_size = cfg.block_size,
        .pattern = .sequential,
    });
    defer engine.deinit();

    engine.dropCache();

    const buffer = try Pattern.generatePattern(
        self.allocator,
        cfg.pattern_type,
        cfg.block_size,
        0xCAFEBABE,
    );
    defer Pattern.freePattern(self.allocator, buffer);

    var latency = Metrics.Latency.init(self.allocator);
    errdefer latency.deinit();

    var total_bytes: u64 = 0;
    var operations: u64 = 0;
    var offset: u64 = 0;

    const start_time = std.time.nanoTimestamp();
    const duration_ns = @as(i128, cfg.duration_seconds) * std.time.ns_per_s;
    var last_progress_time = start_time;

    while (true) {
        const op_start = std.time.nanoTimestamp();
        if (op_start - start_time >= duration_ns) break;

        const bytes_written = try engine.write(offset, buffer);
        const op_end = std.time.nanoTimestamp();

        const latency_ns = op_end - op_start;
        const latency_us = @as(u64, @intCast(@divFloor(latency_ns, std.time.ns_per_us)));
        try latency.record(latency_us);

        total_bytes += bytes_written;
        operations += 1;

        offset += cfg.block_size;
        if (offset >= cfg.file_size) {
            offset = 0;
        }

        // progress callback every 100ms
        if (cfg.progress_callback) |callback| {
            const progress_interval_ns = 100 * std.time.ns_per_ms;
            if (op_end - last_progress_time >= progress_interval_ns) {
                const elapsed_ns_f = @as(f64, @floatFromInt(op_end - start_time));
                const elapsed_s = elapsed_ns_f / @as(f64, std.time.ns_per_s);
                const total_s = @as(f64, @floatFromInt(cfg.duration_seconds));
                const throughput_bps = @as(f64, @floatFromInt(total_bytes)) / elapsed_s;
                callback(elapsed_s, total_s, throughput_bps);
                last_progress_time = op_end;
            }
        }
    }

    try engine.sync();

    const end_time = std.time.nanoTimestamp();
    const elapsed_ns = end_time - start_time;
    const elapsed_ms = @as(u64, @intCast(@divFloor(elapsed_ns, std.time.ns_per_ms)));

    if (cfg.completion_callback) |callback| {
        callback();
    }

    try latency.calculate();

    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_s);
    const throughput_bps = @as(f64, @floatFromInt(total_bytes)) / elapsed_s;

    return .{
        .throughput = .{ .bytes_per_second = throughput_bps },
        .iops = .{ .operations_per_second = operations / cfg.duration_seconds },
        .latency = latency,
        .duration_ms = elapsed_ms,
    };
}

fn runRandomRead(self: *Benchmark, cfg: Config) !BenchmarkMetrics {
    var engine = try IoEngine.init(self.allocator, .{
        .path = cfg.path,
        .mode = cfg.io_mode,
        .file_size = cfg.file_size,
        .block_size = cfg.block_size,
        .pattern = .random,
    });
    defer engine.deinit();

    engine.dropCache();

    const buffer = try Pattern.generatePattern(
        self.allocator,
        .zero,
        cfg.block_size,
        0,
    );
    defer Pattern.freePattern(self.allocator, buffer);

    const max_operations = 100000;
    const offsets = try Pattern.generateRandomOffsets(
        self.allocator,
        cfg.file_size,
        cfg.block_size,
        max_operations,
        0x12345678,
    );
    defer self.allocator.free(offsets);

    var latency = Metrics.Latency.init(self.allocator);
    errdefer latency.deinit();

    var total_bytes: u64 = 0;
    var operations: u64 = 0;
    var offset_index: usize = 0;

    const start_time = std.time.nanoTimestamp();
    const duration_ns = @as(i128, cfg.duration_seconds) * std.time.ns_per_s;
    var last_progress_time = start_time;

    while (true) {
        const op_start = std.time.nanoTimestamp();
        if (op_start - start_time >= duration_ns) break;

        const offset = offsets[offset_index];
        const bytes_read = try engine.read(offset, buffer);
        const op_end = std.time.nanoTimestamp();

        const latency_ns = op_end - op_start;
        const latency_us = @as(u64, @intCast(@divFloor(latency_ns, std.time.ns_per_us)));
        try latency.record(latency_us);

        total_bytes += bytes_read;
        operations += 1;

        offset_index = (offset_index + 1) % offsets.len;

        // progress callback every 100ms
        if (cfg.progress_callback) |callback| {
            const progress_interval_ns = 100 * std.time.ns_per_ms;
            if (op_end - last_progress_time >= progress_interval_ns) {
                const elapsed_ns_f = @as(f64, @floatFromInt(op_end - start_time));
                const elapsed_s = elapsed_ns_f / @as(f64, std.time.ns_per_s);
                const total_s = @as(f64, @floatFromInt(cfg.duration_seconds));
                const throughput_bps = @as(f64, @floatFromInt(total_bytes)) / elapsed_s;
                callback(elapsed_s, total_s, throughput_bps);
                last_progress_time = op_end;
            }
        }
    }

    const end_time = std.time.nanoTimestamp();
    const elapsed_ns = end_time - start_time;
    const elapsed_ms = @as(u64, @intCast(@divFloor(elapsed_ns, std.time.ns_per_ms)));

    if (cfg.completion_callback) |callback| {
        callback();
    }

    try latency.calculate();

    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_s);
    const throughput_bps = @as(f64, @floatFromInt(total_bytes)) / elapsed_s;

    return .{
        .throughput = .{ .bytes_per_second = throughput_bps },
        .iops = .{ .operations_per_second = operations / cfg.duration_seconds },
        .latency = latency,
        .duration_ms = elapsed_ms,
    };
}

fn runRandomWrite(self: *Benchmark, cfg: Config) !BenchmarkMetrics {
    var engine = try IoEngine.init(self.allocator, .{
        .path = cfg.path,
        .mode = cfg.io_mode,
        .file_size = cfg.file_size,
        .block_size = cfg.block_size,
        .pattern = .random,
    });
    defer engine.deinit();

    engine.dropCache();

    const buffer = try Pattern.generatePattern(
        self.allocator,
        cfg.pattern_type,
        cfg.block_size,
        0xDEADC0DE,
    );
    defer Pattern.freePattern(self.allocator, buffer);

    const max_operations = 100000;
    const offsets = try Pattern.generateRandomOffsets(
        self.allocator,
        cfg.file_size,
        cfg.block_size,
        max_operations,
        0x87654321,
    );
    defer self.allocator.free(offsets);

    var latency = Metrics.Latency.init(self.allocator);
    errdefer latency.deinit();

    var total_bytes: u64 = 0;
    var operations: u64 = 0;
    var offset_index: usize = 0;

    const start_time = std.time.nanoTimestamp();
    const duration_ns = @as(i128, cfg.duration_seconds) * std.time.ns_per_s;
    var last_progress_time = start_time;

    while (true) {
        const op_start = std.time.nanoTimestamp();
        if (op_start - start_time >= duration_ns) break;

        const offset = offsets[offset_index];
        const bytes_written = try engine.write(offset, buffer);
        const op_end = std.time.nanoTimestamp();

        const latency_ns = op_end - op_start;
        const latency_us = @as(u64, @intCast(@divFloor(latency_ns, std.time.ns_per_us)));
        try latency.record(latency_us);

        total_bytes += bytes_written;
        operations += 1;

        offset_index = (offset_index + 1) % offsets.len;

        // progress callback every 100ms
        if (cfg.progress_callback) |callback| {
            const progress_interval_ns = 100 * std.time.ns_per_ms;
            if (op_end - last_progress_time >= progress_interval_ns) {
                const elapsed_ns_f = @as(f64, @floatFromInt(op_end - start_time));
                const elapsed_s = elapsed_ns_f / @as(f64, std.time.ns_per_s);
                const total_s = @as(f64, @floatFromInt(cfg.duration_seconds));
                const throughput_bps = @as(f64, @floatFromInt(total_bytes)) / elapsed_s;
                callback(elapsed_s, total_s, throughput_bps);
                last_progress_time = op_end;
            }
        }
    }

    try engine.sync();

    const end_time = std.time.nanoTimestamp();
    const elapsed_ns = end_time - start_time;
    const elapsed_ms = @as(u64, @intCast(@divFloor(elapsed_ns, std.time.ns_per_ms)));

    if (cfg.completion_callback) |callback| {
        callback();
    }

    try latency.calculate();

    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / @as(f64, std.time.ns_per_s);
    const throughput_bps = @as(f64, @floatFromInt(total_bytes)) / elapsed_s;

    return .{
        .throughput = .{ .bytes_per_second = throughput_bps },
        .iops = .{ .operations_per_second = operations / cfg.duration_seconds },
        .latency = latency,
        .duration_ms = elapsed_ms,
    };
}

const BenchmarkMetrics = struct {
    throughput: Metrics.Throughput,
    iops: Metrics.IOPS,
    latency: Metrics.Latency,
    duration_ms: u64,
};
