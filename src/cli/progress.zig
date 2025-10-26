const std = @import("std");
const Terminal = @import("terminal.zig").Terminal;
const Color = @import("terminal.zig").Color;

// spinner styles
pub const SpinnerStyle = enum {
    dots,
    line,
    arc,

    pub fn frames(self: SpinnerStyle) []const []const u8 {
        return switch (self) {
            .dots => &.{ "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
            .line => &.{ "-", "\\", "|", "/" },
            .arc => &.{ "◜", "◠", "◝", "◞", "◡", "◟" },
        };
    }
};

pub const Spinner = struct {
    terminal: Terminal,
    style: SpinnerStyle,
    frame_index: usize,
    message: []const u8,

    pub fn init(terminal: Terminal, style: SpinnerStyle, message: []const u8) Spinner {
        return .{
            .terminal = terminal,
            .style = style,
            .frame_index = 0,
            .message = message,
        };
    }

    // advance to next frame and render
    pub fn tick(self: *Spinner) !void {
        const frames_list = self.style.frames();
        const frame = frames_list[self.frame_index];

        try self.terminal.clearLine();
        try self.terminal.writeColor(.cyan, frame);
        try self.terminal.write(" ");
        try self.terminal.write(self.message);
        try self.terminal.flush();

        self.frame_index = (self.frame_index + 1) % frames_list.len;
    }

    // tick with metrics (spinner + time/throughput)
    pub fn tickWithMetrics(
        self: *Spinner,
        elapsed_s: f64,
        total_s: f64,
        throughput_gbps: f64,
    ) !void {
        const frames_list = self.style.frames();
        const frame = frames_list[self.frame_index];

        try self.terminal.clearLine();
        try self.terminal.writeColor(.cyan, frame);
        try self.terminal.write(" ");
        try self.terminal.write(self.message);
        try self.terminal.printColor(.dim, " {d:.1}s / {d:.1}s  |  ", .{ elapsed_s, total_s });

        // color based on throughput
        const color = if (throughput_gbps >= 5.0)
            Color.green
        else if (throughput_gbps >= 1.0)
            Color.yellow
        else
            Color.red;

        try self.terminal.printColor(color, "{d:.2} Gbps", .{throughput_gbps});
        try self.terminal.flush();

        self.frame_index = (self.frame_index + 1) % frames_list.len;
    }

    // clear the spinner line
    pub fn clear(self: *Spinner) !void {
        try self.terminal.clearLine();
        try self.terminal.flush();
    }

    // finish with success
    pub fn finish(self: *Spinner) !void {
        try self.terminal.clearLine();
        try self.terminal.writeColor(.green, "✓");
        try self.terminal.write(" ");
        try self.terminal.write(self.message);
        try self.terminal.write("\n");
        try self.terminal.flush();
    }

    // finish with error
    pub fn fail(self: *Spinner) !void {
        try self.terminal.clearLine();
        try self.terminal.writeColor(.red, "✗");
        try self.terminal.write(" ");
        try self.terminal.write(self.message);
        try self.terminal.write("\n");
    }
};

pub const ProgressBar = struct {
    terminal: Terminal,
    total: u64,
    current: u64,
    label: []const u8,
    width: usize,

    pub fn init(terminal: Terminal, total: u64, label: []const u8) ProgressBar {
        return .{
            .terminal = terminal,
            .total = total,
            .current = 0,
            .label = label,
            .width = 40,
        };
    }

    // update progress and render
    pub fn update(self: *ProgressBar, current: u64) !void {
        self.current = current;
        try self.render();
    }

    // render progress bar
    fn render(self: *ProgressBar) !void {
        try self.terminal.clearLine();

        // calculate percentage
        const percent = if (self.total > 0) (self.current * 100) / self.total else 0;
        const filled = if (self.total > 0) (self.current * self.width) / self.total else 0;

        // label and bar
        try self.terminal.write(self.label);
        try self.terminal.write(" [");

        // filled portion
        var i: usize = 0;
        while (i < self.width) : (i += 1) {
            if (i < filled) {
                try self.terminal.writeColor(.green, "=");
            } else if (i == filled and filled < self.width) {
                try self.terminal.writeColor(.green, ">");
            } else {
                try self.terminal.write(" ");
            }
        }

        try self.terminal.write("] ");
        try self.terminal.printColor(.bold, "{d}%", .{percent});
    }

    // finish and clear
    pub fn finish(self: *ProgressBar) !void {
        self.current = self.total;
        try self.render();
        try self.terminal.write("\n");
    }
};

// simple live progress updater without bar
pub const LiveProgress = struct {
    terminal: Terminal,
    message: []const u8,

    pub fn init(terminal: Terminal, message: []const u8) LiveProgress {
        return .{
            .terminal = terminal,
            .message = message,
        };
    }

    // update with current metrics
    pub fn update(
        self: *LiveProgress,
        elapsed_s: f64,
        total_s: f64,
        throughput_gbps: f64,
    ) !void {
        try self.terminal.clearLine();
        try self.terminal.write(self.message);
        try self.terminal.printColor(.dim, " {d:.1}s / {d:.1}s  |  ", .{ elapsed_s, total_s });

        // color based on throughput
        const color = if (throughput_gbps >= 5.0)
            Color.green
        else if (throughput_gbps >= 1.0)
            Color.yellow
        else
            Color.red;

        try self.terminal.printColor(color, "{d:.2} Gbps", .{throughput_gbps});
        try self.terminal.flush();
    }

    // finish and clear the line
    pub fn finish(self: *LiveProgress) !void {
        try self.terminal.clearLine();
    }
};

test "spinner frames" {
    const dots = SpinnerStyle.dots.frames();
    try std.testing.expect(dots.len > 0);

    const line = SpinnerStyle.line.frames();
    try std.testing.expectEqual(@as(usize, 4), line.len);
}
