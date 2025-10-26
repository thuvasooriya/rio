const std = @import("std");
const builtin = @import("builtin");
const types = @import("../core/types.zig");

const IoEngine = @This();

pub const Config = struct {
    path: []const u8,
    mode: types.IOMode = .direct,
    file_size: u64,
    block_size: u64 = 4096,
};

file_handle: FileHandle,
config: Config,
allocator: std.mem.Allocator,

const FileHandle = switch (builtin.os.tag) {
    .windows => std.os.windows.HANDLE,
    .linux, .macos => std.posix.fd_t,
    else => @compileError("Unsupported platform"),
};

pub fn init(allocator: std.mem.Allocator, config: Config) !IoEngine {
    const handle = try openFile(config.path, config.mode);

    return .{
        .file_handle = handle,
        .config = config,
        .allocator = allocator,
    };
}

pub fn deinit(self: *IoEngine) void {
    closeFile(self.file_handle);
}

fn openFile(path: []const u8, mode: types.IOMode) !FileHandle {
    return switch (builtin.os.tag) {
        .linux => @import("platform/linux.zig").openDirect(path, mode),
        .macos => @import("platform/darwin.zig").openDirect(path, mode),
        .windows => @import("platform/windows.zig").openDirect(path, mode),
        else => @compileError("Unsupported platform"),
    };
}

fn closeFile(handle: FileHandle) void {
    switch (builtin.os.tag) {
        .linux, .macos => std.posix.close(handle),
        .windows => std.os.windows.CloseHandle(handle),
        else => @compileError("Unsupported platform"),
    }
}

pub fn read(self: *IoEngine, offset: u64, buffer: []u8) !usize {
    return switch (builtin.os.tag) {
        .linux, .macos => try std.posix.pread(self.file_handle, buffer, offset),
        .windows => @import("platform/windows.zig").readFile(self.file_handle, offset, buffer),
        else => @compileError("Unsupported platform"),
    };
}

pub fn write(self: *IoEngine, offset: u64, data: []const u8) !usize {
    return switch (builtin.os.tag) {
        .linux, .macos => try std.posix.pwrite(self.file_handle, data, offset),
        .windows => @import("platform/windows.zig").writeFile(self.file_handle, offset, data),
        else => @compileError("Unsupported platform"),
    };
}

pub fn sync(self: *IoEngine) !void {
    switch (builtin.os.tag) {
        .linux, .macos => try std.posix.fsync(self.file_handle),
        .windows => {
            if (std.os.windows.kernel32.FlushFileBuffers(self.file_handle) == 0) {
                return error.SyncFailed;
            }
        },
        else => @compileError("Unsupported platform"),
    }
}
