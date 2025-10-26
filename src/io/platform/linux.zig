const std = @import("std");
const posix = std.posix;
const linux = std.os.linux;

pub fn openDirect(path: []const u8, mode: anytype) !posix.fd_t {
    const allocator = std.heap.page_allocator;
    const zpath = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{path}, 0);
    defer allocator.free(zpath);

    var oflags: posix.O = .{
        .ACCMODE = .RDWR,
        .CREAT = true,
    };

    switch (mode) {
        .direct => {
            oflags.DIRECT = true;
        },
        .buffered => {},
        .sync => {
            oflags.DIRECT = true;
            oflags.SYNC = true;
        },
    }

    const fd = try posix.openatZ(posix.AT.FDCWD, zpath, oflags, 0o644);
    return fd;
}

pub fn allocAligned(allocator: std.mem.Allocator, size: usize) ![]u8 {
    return allocator.alignedAlloc(u8, std.mem.Alignment.fromByteUnits(4096), size);
}

pub const FadviseHint = enum {
    sequential,
    random,
    drop_cache,
};

pub fn setReadaheadHint(fd: posix.fd_t, hint: FadviseHint) void {
    const advice: usize = switch (hint) {
        .sequential => linux.POSIX_FADV.SEQUENTIAL,
        .random => linux.POSIX_FADV.RANDOM,
        .drop_cache => linux.POSIX_FADV.DONTNEED,
    };
    _ = linux.fadvise(fd, 0, 0, advice);
}

pub fn fastFillFile(fd: posix.fd_t, size: u64, pattern_buffer: []const u8) !void {
    var written: u64 = 0;
    const chunk_size = pattern_buffer.len;

    while (written < size) {
        const to_write = @min(chunk_size, size - written);
        const bytes = try posix.pwrite(fd, pattern_buffer[0..to_write], written);
        written += bytes;
    }

    try posix.fsync(fd);
}
