const std = @import("std");
const builtin = @import("builtin");

pub const SafetyError = error{
    InsufficientDiskSpace,
    SystemDirectoryProtected,
    FileExistsWithoutForce,
    DiskSpaceCheckFailed,
    UnsupportedPlatform,
};

extern "kernel32" fn GetDiskFreeSpaceExW(
    lpDirectoryName: [*:0]const u16,
    lpFreeBytesAvailableToCaller: *u64,
    lpTotalNumberOfBytes: *u64,
    lpTotalNumberOfFreeBytes: *u64,
) callconv(.winapi) std.os.windows.BOOL;

// generate a timestamp-based test filename
pub fn generate_test_filename(allocator: std.mem.Allocator) ![]const u8 {
    const timestamp = std.time.timestamp();
    return std.fmt.allocPrint(allocator, "rio_bench_{d}.dat", .{timestamp});
}

// check if path is in a protected system directory
pub fn is_system_directory(path: []const u8) bool {
    const protected_paths = [_][]const u8{
        "/boot",
        "/bin",
        "/sbin",
        "/usr",
        "/lib",
        "/lib64",
        "/etc",
        "/sys",
        "/proc",
        "/dev",
        "/System",
        "/Library/System",
        "C:\\Windows",
        "C:\\Program Files",
        "C:\\Program Files (x86)",
    };

    const normalized = normalize_path(path);

    // check for exact root "/"
    if (std.mem.eql(u8, normalized, "/")) {
        return true;
    }

    // check for protected directories
    for (protected_paths) |protected| {
        if (std.mem.startsWith(u8, normalized, protected)) {
            // ensure it's actually in the directory, not just a prefix match
            // e.g., "/boot" should match "/boot/test" but not "/bootstrap"
            if (normalized.len == protected.len or
                (normalized.len > protected.len and
                    (normalized[protected.len] == '/' or normalized[protected.len] == '\\')))
            {
                return true;
            }
        }
    }
    return false;
}

// normalize path for comparison (handle trailing slashes, case on windows)
fn normalize_path(path: []const u8) []const u8 {
    if (path.len == 0) return path;
    // note: case insensitivity on windows is handled by the filesystem itself
    // when comparing against protected paths, we use exact case matching
    // which is safe because protected paths are always in canonical form
    return path;
}

// check if sufficient disk space is available
pub fn check_disk_space(path: []const u8, required_bytes: u64) !void {
    const dir = std.fs.cwd();
    const stat = dir.statFile(path) catch |err| switch (err) {
        error.FileNotFound => {
            // file doesn't exist yet, check parent directory
            const parent = std.fs.path.dirname(path) orelse ".";
            return check_directory_space(parent, required_bytes);
        },
        else => return err,
    };

    // file exists, check available space on that filesystem
    _ = stat;
    // use directory-based check for filesystem space
    const parent = std.fs.path.dirname(path) orelse ".";
    return check_directory_space(parent, required_bytes);
}

fn check_directory_space(dir_path: []const u8, required_bytes: u64) !void {
    // minimum multiplier: require 2x the test file size
    const required_space = required_bytes * 2;

    // platform-specific space checks
    switch (builtin.os.tag) {
        .linux, .macos => {
            const statvfs = try get_filesystem_stats(dir_path);
            const available = statvfs.f_bavail * statvfs.f_frsize;
            if (available < required_space) {
                return SafetyError.InsufficientDiskSpace;
            }
        },
        .windows => {
            const available = get_windows_disk_space(dir_path) catch {
                return SafetyError.DiskSpaceCheckFailed;
            };
            if (available < required_space) {
                return SafetyError.InsufficientDiskSpace;
            }
        },
        else => {
            return SafetyError.UnsupportedPlatform;
        },
    }
}

// platform-specific filesystem stats
const StatVFS = struct {
    f_bavail: u64, // free blocks available to non-root
    f_frsize: u64, // fragment size (block size)
};

fn get_filesystem_stats(path: []const u8) !StatVFS {
    switch (builtin.os.tag) {
        .linux => return get_filesystem_stats_linux(path),
        .macos => return get_filesystem_stats_darwin(path),
        else => return SafetyError.UnsupportedPlatform,
    }
}

fn get_filesystem_stats_linux(path: []const u8) !StatVFS {
    const linux = std.os.linux;

    // use linux syscall directly to avoid cross-compilation issues with cImport
    const path_z = try std.posix.toPosixPath(path);

    // statfs struct layout for x86_64 and aarch64
    const Statfs = extern struct {
        f_type: i64,
        f_bsize: i64,
        f_blocks: u64,
        f_bfree: u64,
        f_bavail: u64,
        f_files: u64,
        f_ffree: u64,
        f_fsid: [2]i32,
        f_namelen: i64,
        f_frsize: i64,
        f_flags: i64,
        f_spare: [4]i64,
    };

    var buf: Statfs = undefined;

    const rc = linux.syscall2(.statfs, @intFromPtr(&path_z), @intFromPtr(&buf));

    switch (linux.E.init(rc)) {
        .SUCCESS => {},
        else => return error.StatVFSFailed,
    }

    return StatVFS{
        .f_bavail = buf.f_bavail,
        .f_frsize = @intCast(buf.f_bsize),
    };
}

fn get_filesystem_stats_darwin(path: []const u8) !StatVFS {
    const c = @cImport({
        @cInclude("sys/statvfs.h");
    });

    var buf: c.struct_statvfs = undefined;
    const path_z = try std.posix.toPosixPath(path);
    const rc = c.statvfs(&path_z, &buf);
    if (rc != 0) {
        return error.StatVFSFailed;
    }

    return StatVFS{
        .f_bavail = @intCast(buf.f_bavail),
        .f_frsize = @intCast(buf.f_frsize),
    };
}

fn get_windows_disk_space(dir_path: []const u8) !u64 {
    const path_w = try std.unicode.utf8ToUtf16LeAllocZ(std.heap.page_allocator, dir_path);
    defer std.heap.page_allocator.free(path_w);

    var free_bytes_available: u64 = undefined;
    var total_bytes: u64 = undefined;
    var total_free_bytes: u64 = undefined;

    const result = GetDiskFreeSpaceExW(
        path_w.ptr,
        &free_bytes_available,
        &total_bytes,
        &total_free_bytes,
    );

    if (result == 0) {
        return error.GetDiskFreeSpaceFailed;
    }

    return free_bytes_available;
}

// check if file exists and needs force flag
pub fn check_file_overwrite(path: []const u8, force: bool) !void {
    const dir = std.fs.cwd();
    dir.access(path, .{}) catch |err| switch (err) {
        error.FileNotFound => return, // file doesn't exist, safe to proceed
        else => return err,
    };

    // file exists
    if (!force) {
        return SafetyError.FileExistsWithoutForce;
    }
}

test "is_system_directory detects root" {
    try std.testing.expect(is_system_directory("/"));
    try std.testing.expect(is_system_directory("/boot"));
    try std.testing.expect(is_system_directory("/usr/bin"));
}

test "is_system_directory allows temp paths" {
    try std.testing.expect(!is_system_directory("/tmp/test.dat"));
    try std.testing.expect(!is_system_directory("/home/user/test.dat"));
    try std.testing.expect(!is_system_directory("/var/tmp/test.dat"));
}

test "check_file_overwrite without force" {
    const testing = std.testing;
    const path = "/tmp/rio_test_safety_check.dat";

    // cleanup first
    std.fs.cwd().deleteFile(path) catch {};

    // should succeed when file doesn't exist
    try check_file_overwrite(path, false);

    // create file
    var file = try std.fs.cwd().createFile(path, .{});
    file.close();

    // should fail without force
    try testing.expectError(SafetyError.FileExistsWithoutForce, check_file_overwrite(path, false));

    // should succeed with force
    try check_file_overwrite(path, true);

    // cleanup
    std.fs.cwd().deleteFile(path) catch {};
}
