const std = @import("std");
const windows = std.os.windows;

pub fn openDirect(path: []const u8, mode: anytype) !windows.HANDLE {
    const path_w = try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, path);
    defer std.heap.page_allocator.free(path_w);

    const flags: windows.DWORD = switch (mode) {
        .direct => windows.FILE_FLAG_NO_BUFFERING | windows.FILE_FLAG_WRITE_THROUGH,
        .buffered => 0,
        .sync => windows.FILE_FLAG_WRITE_THROUGH,
    };

    const handle = windows.kernel32.CreateFileW(
        path_w.ptr,
        windows.GENERIC_READ | windows.GENERIC_WRITE,
        windows.FILE_SHARE_READ | windows.FILE_SHARE_WRITE,
        null,
        windows.OPEN_ALWAYS,
        windows.FILE_ATTRIBUTE_NORMAL | flags,
        null,
    );

    if (handle == windows.INVALID_HANDLE_VALUE) {
        return error.OpenFailed;
    }

    return handle;
}

pub fn readFile(handle: windows.HANDLE, offset: u64, buffer: []u8) !usize {
    var overlapped: windows.OVERLAPPED = .{
        .Internal = 0,
        .InternalHigh = 0,
        .DUMMYUNIONNAME = .{ .DUMMYSTRUCTNAME = .{
            .Offset = @truncate(offset),
            .OffsetHigh = @truncate(offset >> 32),
        } },
        .hEvent = null,
    };

    var bytes_read: windows.DWORD = 0;
    if (windows.kernel32.ReadFile(handle, buffer.ptr, @intCast(buffer.len), &bytes_read, &overlapped) == 0) {
        return error.ReadFailed;
    }

    return bytes_read;
}

pub fn writeFile(handle: windows.HANDLE, offset: u64, data: []const u8) !usize {
    var overlapped: windows.OVERLAPPED = .{
        .Internal = 0,
        .InternalHigh = 0,
        .DUMMYUNIONNAME = .{ .DUMMYSTRUCTNAME = .{
            .Offset = @truncate(offset),
            .OffsetHigh = @truncate(offset >> 32),
        } },
        .hEvent = null,
    };

    var bytes_written: windows.DWORD = 0;
    if (windows.kernel32.WriteFile(handle, data.ptr, @intCast(data.len), &bytes_written, &overlapped) == 0) {
        return error.WriteFailed;
    }

    return bytes_written;
}
