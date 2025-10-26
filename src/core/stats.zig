// pure statistical functions
// zero dependencies - foundation layer

const std = @import("std");

// calculate coefficient of variation for a sample set
pub fn coefficient_of_variation(samples: []const f64) f64 {
    if (samples.len == 0) return 0;

    var stats: RunningStats = .{};
    for (samples) |sample| {
        stats.update(sample);
    }

    const mean_val = stats.mean;
    const stddev_val = stats.stddev();

    if (mean_val == 0) return 0;
    return stddev_val / mean_val;
}

// calculate percentile from sorted samples
pub fn percentile(sorted_samples: []const u64, p: f64) u64 {
    if (sorted_samples.len == 0) return 0;
    if (p <= 0) return sorted_samples[0];
    if (p >= 1) return sorted_samples[sorted_samples.len - 1];

    const n = sorted_samples.len;
    const idx_ceil = @as(usize, @intFromFloat(@ceil(@as(f64, @floatFromInt(n)) * p)));
    const idx = if (idx_ceil == 0) 0 else @min(idx_ceil - 1, n - 1);
    return sorted_samples[idx];
}

// running statistics using Welford's online algorithm
pub const RunningStats = struct {
    count: u64 = 0,
    mean: f64 = 0,
    m2: f64 = 0,

    pub fn update(self: *RunningStats, value: f64) void {
        self.count += 1;
        const delta = value - self.mean;
        self.mean += delta / @as(f64, @floatFromInt(self.count));
        const delta2 = value - self.mean;
        self.m2 += delta * delta2;
    }

    pub fn variance(self: RunningStats) f64 {
        if (self.count < 2) return 0;
        return self.m2 / @as(f64, @floatFromInt(self.count - 1));
    }

    pub fn stddev(self: RunningStats) f64 {
        return @sqrt(self.variance());
    }
};

test "coefficient of variation" {
    const samples = [_]f64{ 100, 102, 98, 101, 99 };
    const cov = coefficient_of_variation(&samples);
    try std.testing.expect(cov < 0.05);
}

test "percentile calculation" {
    const samples = [_]u64{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 };
    try std.testing.expectEqual(@as(u64, 10), percentile(&samples, 0.95));
    try std.testing.expectEqual(@as(u64, 5), percentile(&samples, 0.50));
}
