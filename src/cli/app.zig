const std = @import("std");
const Benchmark = @import("../bench/runner.zig");
const Metrics = @import("../bench/metrics.zig");
const Reporter = @import("reporter.zig");
const Args = @import("args.zig");
const format = @import("../core/format.zig");
const safety = @import("../core/safety.zig");
const term_mod = @import("terminal.zig");
const Terminal = term_mod.Terminal;
const Color = term_mod.Color;
const prog = @import("progress.zig");
const version = @import("../version.zig");
const theme = @import("theme.zig");

pub fn run(allocator: std.mem.Allocator) !void {
    const options = Args.parse(allocator) catch |err| {
        switch (err) {
            error.UnknownOption, error.InvalidPattern, error.InvalidMode, error.InvalidSize => {
                try Args.printHelp();
                std.process.exit(1);
            },
            error.MissingValue => {
                std.log.err("Missing value for option", .{});
                try Args.printHelp();
                std.process.exit(1);
            },
            error.MultiplePaths => {
                std.log.err("Only one test file path can be specified", .{});
                std.process.exit(1);
            },
            else => return err,
        }
    };

    if (options.show_help) {
        try Args.printHelp();
        return;
    }

    // default to home directory if not specified
    const target_dir_owned = if (options.target_dir == null)
        std.process.getEnvVarOwned(allocator, "HOME") catch null
    else
        null;
    defer if (target_dir_owned) |owned| allocator.free(owned);
    const target_dir = options.target_dir orelse target_dir_owned orelse ".";

    var stdout_buffer: [4096]u8 = undefined;
    const stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);

    // create terminal with ANSI support (disabled for JSON output)
    const terminal = if (options.json_output)
        Terminal.initNoAnsi(&stdout_writer)
    else
        Terminal.init(&stdout_writer);

    // verify directory exists and is accessible
    var dir = std.fs.cwd().openDir(target_dir, .{}) catch |err| {
        std.log.err("Cannot access directory: {s}", .{target_dir});
        std.log.err("Error: {}", .{err});
        std.process.exit(1);
    };
    dir.close();

    // safety checks on directory
    if (safety.is_system_directory(target_dir)) {
        std.log.err("Cannot benchmark in system directory: {s}", .{target_dir});
        std.log.err("Please use a safe location like /tmp or ~/", .{});
        std.process.exit(1);
    }

    // generate test filename
    const test_filename = try safety.generate_test_filename(allocator);
    defer allocator.free(test_filename);

    // construct full path
    const test_path = try std.fs.path.join(allocator, &[_][]const u8{ target_dir, test_filename });
    defer allocator.free(test_path);

    safety.check_disk_space(target_dir, options.file_size) catch |err| {
        if (err == error.InsufficientDiskSpace) {
            std.log.err("Insufficient disk space for benchmark", .{});
            std.log.err("Required: at least 2x test file size ({d} MB)", .{options.file_size * 2 / (1024 * 1024)});
            std.process.exit(1);
        }
        std.log.warn("Could not verify disk space: {}", .{err});
    };

    safety.check_file_overwrite(test_path, options.force) catch |err| {
        if (err == error.FileExistsWithoutForce) {
            std.log.err("File already exists: {s}", .{test_path});
            std.log.err("Use --force to overwrite", .{});
            std.process.exit(1);
        }
        return err;
    };

    if (!options.json_output) {
        try terminal.print("\n", .{});
    }

    var benchmark = Benchmark.init(allocator);
    defer benchmark.deinit();

    var reporter = Reporter.init(allocator, terminal, options.json_output);
    const pattern_filter = options.pattern orelse .all;

    const patterns = [_]struct {
        name: []const u8,
        io_pattern: Benchmark.IOPattern,
    }{
        .{ .name = "Sequential Read", .io_pattern = .sequential_read },
        .{ .name = "Sequential Write", .io_pattern = .sequential_write },
        .{ .name = "Random Read", .io_pattern = .random_read },
        .{ .name = "Random Write", .io_pattern = .random_write },
    };

    if (options.json_output) {
        try terminal.print("[\n", .{});
        try terminal.flush();
    }

    // prepare header lines for the box (config section)
    const version_line = if (terminal.use_ansi)
        try std.fmt.allocPrint(allocator, "{s}rio{s} {s}v{s}{s}", .{ theme.default.app_name.code(), Color.reset.code(), theme.default.version.code(), version.version, Color.reset.code() })
    else
        try std.fmt.allocPrint(allocator, "rio v{s}", .{version.version});
    defer allocator.free(version_line);

    const size_str = if (options.file_size >= 1024 * 1024 * 1024)
        try std.fmt.allocPrint(allocator, "{d}GB", .{options.file_size / (1024 * 1024 * 1024)})
    else
        try std.fmt.allocPrint(allocator, "{d}MB", .{options.file_size / (1024 * 1024)});
    defer allocator.free(size_str);

    const block_kb = options.block_size / 1024;
    const settings_line = if (terminal.use_ansi)
        try std.fmt.allocPrint(allocator, "{s}{s}{s} · {d}KB blocks · {s}{s}{s} · {d}s  · {s}", .{ theme.default.config_highlight.code(), size_str, Color.reset.code(), block_kb, theme.default.config_highlight.code(), @tagName(options.io_mode), Color.reset.code(), options.duration, target_dir })
    else
        try std.fmt.allocPrint(allocator, "{s} · {d}KB blocks · {s} · {d}s  · {s}", .{ size_str, block_kb, @tagName(options.io_mode), options.duration, target_dir });
    defer allocator.free(settings_line);

    const header_lines = [_][]const u8{ version_line, settings_line };

    // prepare file with spinner inside the box
    if (!options.json_output) {
        const prep_message = if (terminal.use_ansi)
            try std.fmt.allocPrint(allocator, "{s}⠋{s} Preparing test file...", .{ theme.default.spinner.code(), Color.reset.code() })
        else
            try std.fmt.allocPrint(allocator, "⠋ Preparing test file...", .{});
        defer allocator.free(prep_message);

        const prep_lines = [_][]const u8{prep_message};
        const box_line_count = try terminal.printBoxWithDivider(&header_lines, &prep_lines, 66);
        try terminal.flush();

        try benchmark.prepareFile(test_path, options.file_size, options.block_size, options.verbose);

        // clear the box with preparation message
        try terminal.clearLines(box_line_count);
    } else {
        try benchmark.prepareFile(test_path, options.file_size, options.block_size, false);
    }

    // store results for progressive box drawing
    var results = std.ArrayList(Metrics.BenchmarkResult){};
    defer {
        for (results.items) |*result| {
            result.deinit();
        }
        results.deinit(allocator);
    }

    // store content lines (results + spinner)
    var content_lines = std.ArrayList([]u8){};
    defer {
        for (content_lines.items) |line| {
            allocator.free(line);
        }
        content_lines.deinit(allocator);
    }

    // calculate minimum box width based on expected content
    // typical completed line: "✓ Sequential Read    236.67 Mbps ·   61K IOPS ·  16.41μs"
    const min_box_width: usize = 0;

    var box_line_count: usize = 0; // track how many lines the unified box uses
    var first_json = true; // for JSON output comma handling

    for (patterns) |pattern| {
        if (!pattern_filter.matches(pattern.io_pattern)) continue;

        if (options.json_output) {
            if (!first_json) {
                try terminal.print(",\n", .{});
            }
            first_json = false;
        }

        // for non-json output, we'll update the unified box during benchmark
        var current_spinner_line: ?[]u8 = null;
        defer if (current_spinner_line) |line| allocator.free(line);

        // closure for progress callback (to update unified box with spinner)
        const CallbackState = struct {
            var state_terminal: ?Terminal = null;
            var state_allocator: ?std.mem.Allocator = null;
            var state_pattern_name: ?[]const u8 = null;
            var state_header_lines: ?[]const []const u8 = null;
            var state_content_lines: ?*std.ArrayList([]u8) = null;
            var state_box_line_count: ?*usize = null;
            var state_current_spinner_line: ?*?[]u8 = null;
            var state_min_box_width: usize = 0;

            fn progress_callback(elapsed_s: f64, total_s: f64, throughput_bps: f64) void {
                const term = state_terminal orelse return;
                const alloc = state_allocator orelse return;
                const name = state_pattern_name orelse return;
                const headers = state_header_lines orelse return;
                const contents = state_content_lines orelse return;
                const line_count_ptr = state_box_line_count orelse return;
                const spinner_line_ptr = state_current_spinner_line orelse return;
                const min_width = state_min_box_width;

                const throughput_gbps = throughput_bps / 1_000_000_000.0;
                const throughput_color = theme.getThroughputColor(throughput_gbps);

                // build spinner line
                const frames = prog.SpinnerStyle.dots.frames();
                const frame_index = @as(usize, @intFromFloat(elapsed_s * 10.0)) % frames.len;
                const frame = frames[frame_index];

                // build spinner line padded to match completed result line width
                const spinner_line = if (term.use_ansi)
                    std.fmt.allocPrint(
                        alloc,
                        "{s}{s}{s} {s: <18} {s}{d:>3.1}s{s} / {d:.1}s · {s}{d:>4.2} Gbps{s}",
                        .{
                            theme.default.spinner.code(),
                            frame,
                            Color.reset.code(),
                            name,
                            theme.default.elapsed_time.code(),
                            elapsed_s,
                            Color.reset.code(),
                            total_s,
                            throughput_color.code(),
                            throughput_gbps,
                            Color.reset.code(),
                        },
                    ) catch return
                else
                    std.fmt.allocPrint(
                        alloc,
                        "{s} {s: <18} {d:>3.1}s / {d:.1}s · {d:>4.2} Gbps",
                        .{ frame, name, elapsed_s, total_s, throughput_gbps },
                    ) catch return;

                // free previous spinner line
                if (spinner_line_ptr.*) |old| alloc.free(old);
                spinner_line_ptr.* = spinner_line;

                // clear previous box and move cursor up
                if (line_count_ptr.* > 0) {
                    term.flush() catch {}; // flush before clearing
                    term.clearLines(line_count_ptr.*) catch return;
                }

                // build full content array: completed results + spinner
                var full_content = std.ArrayList([]const u8).initCapacity(alloc, contents.items.len + 1) catch return;
                defer full_content.deinit(alloc);

                for (contents.items) |line| {
                    full_content.appendAssumeCapacity(line);
                }
                full_content.appendAssumeCapacity(spinner_line);

                // draw unified box
                const new_line_count = term.printBoxWithDivider(headers, full_content.items, min_width) catch return;
                line_count_ptr.* = new_line_count;
                term.flush() catch {};
            }

            fn completion_callback() void {
                const term = state_terminal orelse return;
                const alloc = state_allocator orelse return;
                const name = state_pattern_name orelse return;
                const headers = state_header_lines orelse return;
                const contents = state_content_lines orelse return;
                const line_count_ptr = state_box_line_count orelse return;
                const spinner_line_ptr = state_current_spinner_line orelse return;
                const min_width = state_min_box_width;

                // show a single frame indicating completion and calculation
                const frames = prog.SpinnerStyle.dots.frames();
                const frame = frames[frames.len - 1];

                // build calculating message line with spinner
                const calc_line = if (term.use_ansi)
                    std.fmt.allocPrint(
                        alloc,
                        "{s}{s}{s} {s: <18} {s}Calculating results...{s}",
                        .{
                            theme.default.spinner.code(),
                            frame,
                            Color.reset.code(),
                            name,
                            theme.default.elapsed_time.code(),
                            Color.reset.code(),
                        },
                    ) catch return
                else
                    std.fmt.allocPrint(
                        alloc,
                        "{s} {s: <18} Calculating results...",
                        .{ frame, name },
                    ) catch return;

                // free previous spinner line
                if (spinner_line_ptr.*) |old| alloc.free(old);
                spinner_line_ptr.* = calc_line;

                // clear previous box
                if (line_count_ptr.* > 0) {
                    term.flush() catch {};
                    term.clearLines(line_count_ptr.*) catch return;
                }

                // build full content array: completed results + calculating message
                var full_content = std.ArrayList([]const u8).initCapacity(alloc, contents.items.len + 1) catch return;
                defer full_content.deinit(alloc);

                for (contents.items) |line| {
                    full_content.appendAssumeCapacity(line);
                }
                full_content.appendAssumeCapacity(calc_line);

                // draw unified box
                const new_line_count = term.printBoxWithDivider(headers, full_content.items, min_width) catch return;
                line_count_ptr.* = new_line_count;
                term.flush() catch {};
            }
        };

        if (!options.json_output) {
            CallbackState.state_terminal = terminal;
            CallbackState.state_allocator = allocator;
            CallbackState.state_pattern_name = pattern.name;
            CallbackState.state_header_lines = &header_lines;
            CallbackState.state_content_lines = &content_lines;
            CallbackState.state_box_line_count = &box_line_count;
            CallbackState.state_current_spinner_line = &current_spinner_line;
            CallbackState.state_min_box_width = min_box_width;
        }

        const config: Benchmark.Config = .{
            .path = test_path,
            .duration_seconds = options.duration,
            .block_size = options.block_size,
            .file_size = options.file_size,
            .io_mode = options.io_mode,
            .pattern_type = .random,
            .progress_callback = if (!options.json_output) &CallbackState.progress_callback else null,
            .completion_callback = if (!options.json_output) &CallbackState.completion_callback else null,
            .verbose = options.verbose,
        };

        var result = try benchmark.run(pattern.name, config, pattern.io_pattern);

        if (options.json_output) {
            try reporter.printJson(&result);
            try terminal.flush();
            result.deinit();
        } else {
            // add result to list
            try results.append(allocator, result);

            // clear previous box
            if (box_line_count > 0) {
                try terminal.flush(); // flush before clearing
                try terminal.clearLines(box_line_count);
            }

            // clear content lines and rebuild with all results
            for (content_lines.items) |line| {
                allocator.free(line);
            }
            content_lines.clearRetainingCapacity();

            // build result lines
            for (results.items) |*res| {
                const gbps = res.throughput.toGBps();
                var throughput_value: f64 = undefined;
                var throughput_unit: []const u8 = undefined;

                if (gbps >= 1.0) {
                    throughput_value = gbps;
                    throughput_unit = "Gbps";
                } else {
                    throughput_value = res.throughput.toMBps();
                    throughput_unit = "Mbps";
                }

                var iops_buffer: [32]u8 = undefined;
                const iops_str = try Reporter.formatIOPS(res.iops.operations_per_second, &iops_buffer);

                const throughput_color = theme.getThroughputColor(gbps);
                const latency_color = theme.getLatencyColor(res.latency.avg_us);

                const line = if (terminal.use_ansi)
                    try std.fmt.allocPrint(
                        allocator,
                        "{s}✓{s} {s: <18} {s}{d:>6.2} {s: <4}{s} · {s}{s: >5} IOPS{s} · {s}{d:>6.2}μs{s}",
                        .{
                            theme.default.checkmark.code(),
                            Color.reset.code(),
                            res.test_name,
                            throughput_color.code(),
                            throughput_value,
                            throughput_unit,
                            Color.reset.code(),
                            Color.bold.code(),
                            iops_str,
                            Color.reset.code(),
                            latency_color.code(),
                            res.latency.avg_us,
                            Color.reset.code(),
                        },
                    )
                else
                    try std.fmt.allocPrint(
                        allocator,
                        "✓ {s: <18} {d:>6.2} {s: <4} · {s: >5} IOPS · {d:>6.2}μs",
                        .{ res.test_name, throughput_value, throughput_unit, iops_str, res.latency.avg_us },
                    );
                try content_lines.append(allocator, line);
            }

            // draw unified box with all completed results
            box_line_count = try terminal.printBoxWithDivider(&header_lines, content_lines.items, min_box_width);
            try terminal.flush();

            // clear callback state
            CallbackState.state_terminal = null;
            CallbackState.state_allocator = null;
            CallbackState.state_pattern_name = null;
            CallbackState.state_header_lines = null;
            CallbackState.state_content_lines = null;
            CallbackState.state_box_line_count = null;
            CallbackState.state_current_spinner_line = null;
        }
    }

    if (options.json_output) {
        try terminal.print("\n]\n", .{});
        try terminal.flush();
    }

    std.fs.cwd().deleteFile(test_path) catch |err| {
        std.log.warn("Failed to clean up test file: {}", .{err});
    };
}
