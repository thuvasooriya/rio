const Color = @import("terminal.zig").Color;

// centralized color theme for rio output
pub const Theme = struct {
    // box styling
    border: Color = .gray,

    // header styling
    app_name: Color = .green,
    version: Color = .blue,
    config_highlight: Color = .bold,

    // progress indicators
    spinner: Color = .cyan,
    checkmark: Color = .green,
    elapsed_time: Color = .dim,

    // metric colors (determined by thresholds)
    pub const throughput_thresholds = struct {
        pub const high: f64 = 5.0; // >= 5 Gbps
        pub const medium: f64 = 1.0; // >= 1 Gbps
    };

    pub const latency_thresholds = struct {
        pub const low: f64 = 1.0; // < 1 μs
        pub const medium: f64 = 10.0; // < 10 μs
    };
};

// default theme instance
pub const default = Theme{};

// color helpers based on thresholds
pub fn getThroughputColor(gbps: f64) Color {
    if (gbps >= Theme.throughput_thresholds.high) return .green;
    if (gbps >= Theme.throughput_thresholds.medium) return .cyan;
    return .yellow;
}

pub fn getLatencyColor(latency_us: f64) Color {
    if (latency_us < Theme.latency_thresholds.low) return .green;
    if (latency_us < Theme.latency_thresholds.medium) return .cyan;
    return .yellow;
}
