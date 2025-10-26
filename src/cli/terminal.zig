const std = @import("std");

// ANSI escape codes for terminal control
pub const Color = enum {
    reset,
    bold,
    dim,
    red,
    green,
    yellow,
    blue,
    cyan,
    magenta,

    pub fn code(self: Color) []const u8 {
        return switch (self) {
            .reset => "\x1b[0m",
            .bold => "\x1b[1m",
            .dim => "\x1b[2m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .cyan => "\x1b[36m",
            .magenta => "\x1b[35m",
        };
    }
};

pub const Terminal = struct {
    writer: *std.fs.File.Writer,
    use_ansi: bool,

    pub fn init(writer: *std.fs.File.Writer) Terminal {
        return .{
            .writer = writer,
            .use_ansi = detectAnsiSupport(),
        };
    }

    pub fn initNoAnsi(writer: *std.fs.File.Writer) Terminal {
        return .{
            .writer = writer,
            .use_ansi = false,
        };
    }

    // clear current line
    pub fn clearLine(self: Terminal) !void {
        if (!self.use_ansi) return;
        try self.writer.interface.writeAll("\x1b[2K\r");
    }

    // clear from cursor to end of screen
    pub fn clearToEnd(self: Terminal) !void {
        if (!self.use_ansi) return;
        try self.writer.interface.writeAll("\x1b[0J");
    }

    // clear n lines by moving up, then clearing to end of screen
    pub fn clearLines(self: Terminal, n: usize) !void {
        if (!self.use_ansi or n == 0) return;

        // move cursor up n lines
        try self.writer.interface.print("\x1b[{d}A\r", .{n});

        // clear from cursor to end of screen
        try self.clearToEnd();
    }

    // move cursor up n lines
    pub fn cursorUp(self: Terminal, n: usize) !void {
        if (!self.use_ansi) return;
        try self.writer.interface.print("\x1b[{d}A", .{n});
    }

    // move cursor down n lines
    pub fn cursorDown(self: Terminal, n: usize) !void {
        if (!self.use_ansi) return;
        try self.writer.interface.print("\x1b[{d}B", .{n});
    }

    // move cursor to column
    pub fn cursorToColumn(self: Terminal, col: usize) !void {
        if (!self.use_ansi) return;
        try self.writer.interface.print("\x1b[{d}G", .{col});
    }

    // hide cursor
    pub fn hideCursor(self: Terminal) !void {
        if (!self.use_ansi) return;
        try self.writer.interface.writeAll("\x1b[?25l");
    }

    // show cursor
    pub fn showCursor(self: Terminal) !void {
        if (!self.use_ansi) return;
        try self.writer.interface.writeAll("\x1b[?25h");
    }

    // write with color
    pub fn writeColor(self: Terminal, color: Color, text: []const u8) !void {
        if (self.use_ansi) {
            try self.writer.interface.writeAll(color.code());
            try self.writer.interface.writeAll(text);
            try self.writer.interface.writeAll(Color.reset.code());
        } else {
            try self.writer.interface.writeAll(text);
        }
    }

    // print with color
    pub fn printColor(self: Terminal, color: Color, comptime fmt: []const u8, args: anytype) !void {
        if (self.use_ansi) {
            try self.writer.interface.writeAll(color.code());
            try self.writer.interface.print(fmt, args);
            try self.writer.interface.writeAll(Color.reset.code());
        } else {
            try self.writer.interface.print(fmt, args);
        }
    }

    // write plain text
    pub fn write(self: Terminal, text: []const u8) !void {
        try self.writer.interface.writeAll(text);
    }

    // print formatted text
    pub fn print(self: Terminal, comptime fmt: []const u8, args: anytype) !void {
        try self.writer.interface.print(fmt, args);
    }

    // flush output
    pub fn flush(self: Terminal) !void {
        try self.writer.interface.flush();
    }

    // draw a rounded corner box around text
    pub fn printBox(self: Terminal, lines: []const []const u8) !void {
        if (lines.len == 0) return;

        // find max width
        var max_width: usize = 0;
        for (lines) |line| {
            if (line.len > max_width) max_width = line.len;
        }

        // box drawing characters (rounded corners)
        const top_left = "╭";
        const top_right = "╮";
        const bottom_left = "╰";
        const bottom_right = "╯";
        const horizontal = "─";
        const vertical = "│";

        // top border
        try self.write(top_left);
        var i: usize = 0;
        while (i < max_width + 2) : (i += 1) {
            try self.write(horizontal);
        }
        try self.write(top_right);
        try self.write("\n");

        // content lines
        for (lines) |line| {
            try self.write(vertical);
            try self.write(" ");
            try self.write(line);
            // pad to max width
            const padding = max_width - line.len;
            var j: usize = 0;
            while (j < padding) : (j += 1) {
                try self.write(" ");
            }
            try self.write(" ");
            try self.write(vertical);
            try self.write("\n");
        }

        // bottom border
        try self.write(bottom_left);
        i = 0;
        while (i < max_width + 2) : (i += 1) {
            try self.write(horizontal);
        }
        try self.write(bottom_right);
        try self.write("\n");
    }

    // calculate visual width of a string, ignoring ANSI escape codes
    fn visualWidth(text: []const u8) usize {
        var width: usize = 0;
        var i: usize = 0;
        while (i < text.len) {
            if (text[i] == 0x1b and i + 1 < text.len and text[i + 1] == '[') {
                // skip ANSI escape sequence
                i += 2;
                while (i < text.len and text[i] != 'm') : (i += 1) {}
                i += 1; // skip the 'm'
            } else {
                // count UTF-8 characters properly
                const byte = text[i];
                if (byte < 0x80) {
                    width += 1;
                    i += 1;
                } else if (byte < 0xE0) {
                    width += 1;
                    i += 2;
                } else if (byte < 0xF0) {
                    width += 1;
                    i += 3;
                } else {
                    width += 1;
                    i += 4;
                }
            }
        }
        return width;
    }

    // draw a box with header section and content section separated by a divider
    // returns the number of lines printed
    pub fn printBoxWithDivider(
        self: Terminal,
        header_lines: []const []const u8,
        content_lines: []const []const u8,
        min_width: usize,
    ) !usize {
        if (header_lines.len == 0 and content_lines.len == 0) return 0;

        // find max width across both sections, but respect min_width
        var max_width: usize = min_width;
        for (header_lines) |line| {
            const width = visualWidth(line);
            if (width > max_width) max_width = width;
        }
        for (content_lines) |line| {
            const width = visualWidth(line);
            if (width > max_width) max_width = width;
        }

        // box drawing characters
        const top_left = "╭";
        const top_right = "╮";
        const bottom_left = "╰";
        const bottom_right = "╯";
        const horizontal = "─";
        const vertical = "│";
        const divider_left = "├";
        const divider_right = "┤";

        var line_count: usize = 0;

        // top border
        try self.write(top_left);
        var i: usize = 0;
        while (i < max_width + 2) : (i += 1) {
            try self.write(horizontal);
        }
        try self.write(top_right);
        try self.write("\n");
        line_count += 1;

        // header lines
        for (header_lines) |line| {
            try self.write(vertical);
            try self.write(" ");
            try self.write(line);
            const padding = max_width - visualWidth(line);
            var j: usize = 0;
            while (j < padding) : (j += 1) {
                try self.write(" ");
            }
            try self.write(" ");
            try self.write(vertical);
            try self.write("\n");
            line_count += 1;
        }

        // divider (only if we have content)
        if (content_lines.len > 0) {
            try self.write(divider_left);
            i = 0;
            while (i < max_width + 2) : (i += 1) {
                try self.write(horizontal);
            }
            try self.write(divider_right);
            try self.write("\n");
            line_count += 1;
        }

        // content lines
        for (content_lines) |line| {
            try self.write(vertical);
            try self.write(" ");
            try self.write(line);
            const padding = max_width - visualWidth(line);
            var j: usize = 0;
            while (j < padding) : (j += 1) {
                try self.write(" ");
            }
            try self.write(" ");
            try self.write(vertical);
            try self.write("\n");
            line_count += 1;
        }

        // bottom border
        try self.write(bottom_left);
        i = 0;
        while (i < max_width + 2) : (i += 1) {
            try self.write(horizontal);
        }
        try self.write(bottom_right);
        try self.write("\n");
        line_count += 1;

        return line_count;
    }
};

// detect if terminal supports ANSI codes
fn detectAnsiSupport() bool {
    // check if stdout is a terminal
    const stdout_file = std.fs.File.stdout();
    if (!stdout_file.isTty()) return false;

    const builtin = @import("builtin");

    // on Windows, check for NO_COLOR using process API
    if (builtin.os.tag == .windows) {
        // simple approach: assume Windows 10+ with VT support
        // check NO_COLOR via GetEnvironmentVariableW would be complex
        return true;
    }

    // on Unix, check environment variables
    if (std.posix.getenv("NO_COLOR")) |_| return false;
    if (std.posix.getenv("TERM")) |term| {
        if (std.mem.eql(u8, term, "dumb")) return false;
    }

    return true;
}

test "color codes" {
    try std.testing.expectEqualStrings("\x1b[0m", Color.reset.code());
    try std.testing.expectEqualStrings("\x1b[32m", Color.green.code());
    try std.testing.expectEqualStrings("\x1b[31m", Color.red.code());
}
