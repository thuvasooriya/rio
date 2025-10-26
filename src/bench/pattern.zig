const std = @import("std");

const Pattern = @This();

pub const PatternType = enum {
    sequential,
    random,
    zero,
    ones,
    random_compressible,
};

pub fn generatePattern(
    allocator: std.mem.Allocator,
    pattern_type: PatternType,
    size: usize,
    seed: u64,
) ![]align(4096) u8 {
    const buffer = try allocator.alignedAlloc(u8, std.mem.Alignment.fromByteUnits(4096), size);
    errdefer allocator.free(buffer);

    switch (pattern_type) {
        .zero => {
            @memset(buffer, 0);
        },
        .ones => {
            @memset(buffer, 0xFF);
        },
        .random => {
            var prng = std.Random.DefaultPrng.init(seed);
            const random = prng.random();
            random.bytes(buffer);
        },
        .sequential => {
            for (buffer, 0..) |*byte, i| {
                byte.* = @intCast(i % 256);
            }
        },
        .random_compressible => {
            var prng = std.Random.DefaultPrng.init(seed);
            const random = prng.random();
            for (buffer) |*byte| {
                byte.* = if (random.boolean()) 0 else random.int(u8);
            }
        },
    }

    return buffer;
}

pub fn freePattern(allocator: std.mem.Allocator, buffer: []align(4096) u8) void {
    allocator.free(buffer);
}

pub fn generateRandomOffsets(
    allocator: std.mem.Allocator,
    file_size: u64,
    block_size: u64,
    count: usize,
    seed: u64,
) ![]u64 {
    const offsets = try allocator.alloc(u64, count);
    errdefer allocator.free(offsets);

    var prng = std.Random.DefaultPrng.init(seed);
    const random = prng.random();

    const max_offset = (file_size / block_size) * block_size;

    for (offsets) |*offset| {
        offset.* = (random.int(u64) % (max_offset / block_size)) * block_size;
    }

    return offsets;
}

test "pattern generation" {
    const allocator = std.testing.allocator;

    const buffer = try generatePattern(allocator, .zero, 4096, 0);
    defer freePattern(allocator, buffer);

    for (buffer) |byte| {
        try std.testing.expectEqual(@as(u8, 0), byte);
    }
}
