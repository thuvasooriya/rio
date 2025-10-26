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
