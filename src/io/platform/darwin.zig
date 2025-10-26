const std = @import("std");
const posix = std.posix;
const c = @cImport({
    @cInclude("fcntl.h");
});

pub fn openDirect(path: []const u8, mode: anytype) !posix.fd_t {
    const allocator = std.heap.page_allocator;
    const zpath = try std.mem.concatWithSentinel(allocator, u8, &[_][]const u8{path}, 0);
    defer allocator.free(zpath);

    const oflags: posix.O = .{
        .ACCMODE = .RDWR,
        .CREAT = true,
    };

    switch (mode) {
        .direct => {},
        .buffered => {},
        .sync => {},
    }

    const fd = try posix.openatZ(posix.AT.FDCWD, zpath, oflags, 0o644);

    if (mode == .direct or mode == .sync) {
        _ = c.fcntl(fd, c.F_NOCACHE, @as(c_int, 1));
    }

    return fd;
}

pub fn fullSync(fd: posix.fd_t) !void {
    if (c.fcntl(fd, c.F_FULLFSYNC) != 0) {
        return error.SyncFailed;
    }
}

pub const FadviseHint = enum {
    sequential,
    random,
    drop_cache,
};

pub fn setReadaheadHint(fd: posix.fd_t, hint: FadviseHint) void {
    _ = fd;
    _ = hint;
}

pub fn fastFillFile(fd: posix.fd_t, size: u64, pattern_buffer: []const u8) !void {
    var written: u64 = 0;
    const chunk_size = pattern_buffer.len;

    while (written < size) {
        const to_write = @min(chunk_size, size - written);
        const bytes = try posix.pwrite(fd, pattern_buffer[0..to_write], written);
        written += bytes;
    }

    try fullSync(fd);
}
