const std = @import("std");
const posix = std.posix;

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
