const std = @import("std");

const Metrics = @This();

allocator: std.mem.Allocator,

pub const Throughput = struct {
    bytes_per_second: f64,

    pub fn toMBps(self: Throughput) f64 {
        return self.bytes_per_second / (1024.0 * 1024.0);
    }

    pub fn toGBps(self: Throughput) f64 {
        return self.bytes_per_second / (1024.0 * 1024.0 * 1024.0);
    }

    pub fn autoUnit(self: Throughput) SpeedMeasurement {
        const mbps = self.toMBps();
        if (mbps >= 1000.0) {
            return .{ .value = self.toGBps(), .unit = .gbps };
        } else if (mbps >= 1.0) {
            return .{ .value = mbps, .unit = .mbps };
        } else {
            return .{ .value = self.bytes_per_second / 1024.0, .unit = .kbps };
        }
    }
};

pub const IOPS = struct {
    operations_per_second: u64,
};

pub const Latency = struct {
    min_us: u64,
    max_us: u64,
    avg_us: f64,
    p95_us: u64,
    p99_us: u64,
    samples: std.ArrayList(u64),
    allocator: std.mem.Allocator,
    total_count: u64,
    total_sum: u64,
    rng: std.Random.DefaultPrng,

    const MAX_SAMPLES: usize = 10000; // reservoir sampling limit

    pub fn init(allocator: std.mem.Allocator) Latency {
        return .{
            .min_us = std.math.maxInt(u64),
            .max_us = 0,
            .avg_us = 0,
            .p95_us = 0,
            .p99_us = 0,
            .samples = std.ArrayList(u64){},
            .allocator = allocator,
            .total_count = 0,
            .total_sum = 0,
            .rng = std.Random.DefaultPrng.init(@intCast(std.time.nanoTimestamp())),
        };
    }

    pub fn deinit(self: *Latency) void {
        self.samples.deinit(self.allocator);
    }

    pub fn record(self: *Latency, latency_us: u64) !void {
        self.min_us = @min(self.min_us, latency_us);
        self.max_us = @max(self.max_us, latency_us);
        self.total_sum += latency_us;
        self.total_count += 1;

        // reservoir sampling: keep fixed number of samples
        if (self.samples.items.len < MAX_SAMPLES) {
            try self.samples.append(self.allocator, latency_us);
        } else {
            // randomly replace an existing sample using persistent RNG
            const idx = self.rng.random().uintLessThan(u64, self.total_count);
            if (idx < MAX_SAMPLES) {
                self.samples.items[@intCast(idx)] = latency_us;
            }
        }
    }

    pub fn calculate(self: *Latency) !void {
        if (self.total_count == 0) return;

        // use accurate average from all samples
        self.avg_us = @as(f64, @floatFromInt(self.total_sum)) / @as(f64, @floatFromInt(self.total_count));

        // percentiles from reservoir sample (fast sort of max 10k items)
        if (self.samples.items.len > 0) {
            std.mem.sort(u64, self.samples.items, {}, std.sort.asc(u64));

            const stats = @import("../core/stats.zig");
            self.p95_us = stats.percentile(self.samples.items, 0.95);
            self.p99_us = stats.percentile(self.samples.items, 0.99);
        }
    }
};

pub const BenchmarkResult = struct {
    test_name: []const u8,
    throughput: Throughput,
    iops: IOPS,
    latency: Latency,
    duration_ms: u64,

    pub fn deinit(self: *BenchmarkResult) void {
        self.latency.deinit();
    }
};

pub const SpeedMeasurement = struct {
    value: f64,
    unit: SpeedUnit,
};

pub const SpeedUnit = enum {
    bps,
    kbps,
    mbps,
    gbps,

    pub fn toString(self: SpeedUnit) []const u8 {
        return switch (self) {
            .bps => "bps",
            .kbps => "Kbps",
            .mbps => "Mbps",
            .gbps => "Gbps",
        };
    }
};

pub fn init(allocator: std.mem.Allocator) Metrics {
    return .{ .allocator = allocator };
}

pub fn deinit(self: *Metrics) void {
    _ = self;
}
