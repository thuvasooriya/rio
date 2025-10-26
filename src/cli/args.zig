const std = @import("std");
const Benchmark = @import("../bench/runner.zig");
const types = @import("../core/types.zig");
const version = @import("../version.zig");

const Args = @This();

pub const Options = struct {
    target_dir: ?[]const u8 = null,
    file_size: u64 = 1024 * 1024 * 1024,
    block_size: usize = 4 * 1024,
    duration: u32 = 5,
    io_mode: types.IOMode = .buffered,
    pattern: ?PatternFilter = null,
    json_output: bool = false,
    show_help: bool = false,
    force: bool = false,
    verbose: bool = false,
};

pub const PatternFilter = enum {
    seq_read,
    seq_write,
    rand_read,
    rand_write,
    all,

    pub fn fromString(s: []const u8) ?PatternFilter {
        if (std.mem.eql(u8, s, "seq-read")) return .seq_read;
        if (std.mem.eql(u8, s, "sequential-read")) return .seq_read;
        if (std.mem.eql(u8, s, "seq-write")) return .seq_write;
        if (std.mem.eql(u8, s, "sequential-write")) return .seq_write;
        if (std.mem.eql(u8, s, "rand-read")) return .rand_read;
        if (std.mem.eql(u8, s, "random-read")) return .rand_read;
        if (std.mem.eql(u8, s, "rand-write")) return .rand_write;
        if (std.mem.eql(u8, s, "random-write")) return .rand_write;
        if (std.mem.eql(u8, s, "all")) return .all;
        return null;
    }

    pub fn matches(self: PatternFilter, pattern: Benchmark.IOPattern) bool {
        return switch (self) {
            .all => true,
            .seq_read => pattern == .sequential_read,
            .seq_write => pattern == .sequential_write,
            .rand_read => pattern == .random_read,
            .rand_write => pattern == .random_write,
        };
    }
};

pub fn parse(allocator: std.mem.Allocator) !Options {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip();

    var options: Options = .{};

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            options.show_help = true;
        } else if (std.mem.eql(u8, arg, "--json")) {
            options.json_output = true;
        } else if (std.mem.eql(u8, arg, "--force") or std.mem.eql(u8, arg, "-f")) {
            options.force = true;
        } else if (std.mem.eql(u8, arg, "--verbose") or std.mem.eql(u8, arg, "-v")) {
            options.verbose = true;
        } else if (std.mem.eql(u8, arg, "--size")) {
            const value = args.next() orelse return error.MissingValue;
            options.file_size = try parseSize(value);
        } else if (std.mem.eql(u8, arg, "--block-size")) {
            const value = args.next() orelse return error.MissingValue;
            const size = try parseSize(value);
            options.block_size = @intCast(size);
        } else if (std.mem.eql(u8, arg, "--duration")) {
            const value = args.next() orelse return error.MissingValue;
            options.duration = try parseDuration(value);
        } else if (std.mem.eql(u8, arg, "--mode")) {
            const value = args.next() orelse return error.MissingValue;
            options.io_mode = try parseMode(value);
        } else if (std.mem.eql(u8, arg, "--pattern")) {
            const value = args.next() orelse return error.MissingValue;
            options.pattern = PatternFilter.fromString(value) orelse return error.InvalidPattern;
        } else if (std.mem.startsWith(u8, arg, "--")) {
            std.log.err("Unknown option: {s}", .{arg});
            return error.UnknownOption;
        } else {
            if (options.target_dir != null) {
                std.log.err("Multiple paths specified", .{});
                return error.MultiplePaths;
            }
            options.target_dir = arg;
        }
    }

    return options;
}

fn parseSize(s: []const u8) !u64 {
    if (s.len == 0) return error.InvalidSize;

    var multiplier: u64 = 1;
    var num_str = s;

    if (s[s.len - 1] == 'B' or s[s.len - 1] == 'b') {
        if (s.len < 2) return error.InvalidSize;
        const suffix = s[s.len - 2];
        num_str = s[0 .. s.len - 2];

        multiplier = switch (suffix) {
            'K', 'k' => 1024,
            'M', 'm' => 1024 * 1024,
            'G', 'g' => 1024 * 1024 * 1024,
            'T', 't' => 1024 * 1024 * 1024 * 1024,
            else => return error.InvalidSize,
        };
    } else {
        const suffix = s[s.len - 1];
        if (suffix == 'K' or suffix == 'k' or
            suffix == 'M' or suffix == 'm' or
            suffix == 'G' or suffix == 'g' or
            suffix == 'T' or suffix == 't')
        {
            num_str = s[0 .. s.len - 1];
            multiplier = switch (suffix) {
                'K', 'k' => 1024,
                'M', 'm' => 1024 * 1024,
                'G', 'g' => 1024 * 1024 * 1024,
                'T', 't' => 1024 * 1024 * 1024 * 1024,
                else => unreachable,
            };
        }
    }

    const num = try std.fmt.parseInt(u64, num_str, 10);
    return num * multiplier;
}

fn parseDuration(s: []const u8) !u32 {
    if (s.len == 0) return error.InvalidDuration;

    var num_str = s;

    // check for 's' suffix and strip it
    if (s[s.len - 1] == 's' or s[s.len - 1] == 'S') {
        num_str = s[0 .. s.len - 1];
    }

    return try std.fmt.parseInt(u32, num_str, 10);
}

fn parseMode(s: []const u8) !types.IOMode {
    if (std.mem.eql(u8, s, "buffered")) return .buffered;
    if (std.mem.eql(u8, s, "direct")) return .direct;
    if (std.mem.eql(u8, s, "sync")) return .sync;
    return error.InvalidMode;
}

pub fn printHelp() !void {
    var buffer: [4096]u8 = undefined;
    var writer_obj = std.fs.File.stdout().writer(&buffer);
    const out = &writer_obj.interface;

    try out.print(
        \\rio v{s} - Cross-Platform Disk Benchmark Tool
        \\
        \\USAGE:
        \\    rio <directory> [OPTIONS]
        \\
        \\ARGUMENTS:
        \\    <directory>         Directory to benchmark (default: current directory)
        \\                        Test file will be auto-generated with timestamp
        \\
        \\OPTIONS:
        \\    --size <size>           Test file size (default: 1G)
        \\                            Suffixes: K, M, G, T (e.g., 1G, 512M, 4096K)
        \\
        \\    --block-size <size>     I/O block size (default: 4K)
        \\                            Suffixes: K, M (e.g., 4K, 1M, 128K)
        \\
        \\    --duration <seconds>    Test duration per pattern (default: 5)
        \\
        \\    --mode <mode>           I/O mode (default: buffered)
        \\                            Options: buffered, direct, sync
        \\                            - buffered: Use OS page cache
        \\                            - direct:   Bypass cache (O_DIRECT)
        \\                            - sync:     Synchronous writes
        \\
        \\    --pattern <pattern>     Run specific pattern only (default: all)
        \\                            Options: seq-read, seq-write, rand-read,
        \\                                     rand-write, all
        \\
        \\    --json                  Output results in JSON format
        \\
        \\    --force, -f             Allow overwriting existing test files
        \\
        \\    --verbose, -v           Show detailed debug logs
        \\
        \\    --help, -h              Show this help message
        \\
        \\EXAMPLES:
        \\    # Benchmark current directory
        \\    rio .
        \\
        \\    # Benchmark specific directory
        \\    rio /tmp
        \\
        \\    # Custom size and duration
        \\    rio /mnt/external --size 1G --duration 10
        \\
        \\    # Direct I/O mode (bypass cache)
        \\    rio . --mode direct
        \\
        \\    # Run only random read test
        \\    rio . --pattern rand-read
        \\
        \\    # JSON output for scripting
        \\    rio /tmp --json > results.json
        \\
        \\NOTES:
        \\    - Test files are automatically named rio_bench_<timestamp>.dat
        \\    - Test files are cleaned up after benchmark completes
        \\    - Directory must have sufficient free space (2x test file size)
        \\    - System directories are protected and cannot be benchmarked
        \\
    , .{version.version});

    try out.flush();
}

test "parseSize with suffixes" {
    try std.testing.expectEqual(@as(u64, 1024), try parseSize("1K"));
    try std.testing.expectEqual(@as(u64, 1024), try parseSize("1k"));
    try std.testing.expectEqual(@as(u64, 1024), try parseSize("1KB"));
    try std.testing.expectEqual(@as(u64, 1024), try parseSize("1kb"));

    try std.testing.expectEqual(@as(u64, 1024 * 1024), try parseSize("1M"));
    try std.testing.expectEqual(@as(u64, 1024 * 1024), try parseSize("1m"));
    try std.testing.expectEqual(@as(u64, 1024 * 1024), try parseSize("1MB"));

    try std.testing.expectEqual(@as(u64, 1024 * 1024 * 1024), try parseSize("1G"));
    try std.testing.expectEqual(@as(u64, 1024 * 1024 * 1024), try parseSize("1GB"));

    try std.testing.expectEqual(@as(u64, 256 * 1024 * 1024), try parseSize("256M"));
    try std.testing.expectEqual(@as(u64, 4 * 1024), try parseSize("4K"));

    try std.testing.expectEqual(@as(u64, 512), try parseSize("512"));
}

test "parseMode" {
    try std.testing.expectEqual(types.IOMode.buffered, try parseMode("buffered"));
    try std.testing.expectEqual(types.IOMode.direct, try parseMode("direct"));
    try std.testing.expectEqual(types.IOMode.sync, try parseMode("sync"));

    try std.testing.expectError(error.InvalidMode, parseMode("invalid"));
}

test "PatternFilter.fromString" {
    try std.testing.expectEqual(PatternFilter.seq_read, PatternFilter.fromString("seq-read").?);
    try std.testing.expectEqual(PatternFilter.seq_read, PatternFilter.fromString("sequential-read").?);
    try std.testing.expectEqual(PatternFilter.rand_write, PatternFilter.fromString("rand-write").?);
    try std.testing.expectEqual(PatternFilter.all, PatternFilter.fromString("all").?);
    try std.testing.expectEqual(@as(?PatternFilter, null), PatternFilter.fromString("invalid"));
}
