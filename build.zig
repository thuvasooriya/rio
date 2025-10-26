const std = @import("std");

const Manifest = struct {
    version: []const u8,
};

fn getVersion(b: *std.Build) []const u8 {
    var diagnostics: std.zon.parse.Diagnostics = .{};
    defer diagnostics.deinit(b.allocator);

    const manifest = std.zon.parse.fromSlice(
        Manifest,
        b.allocator,
        @embedFile("build.zig.zon"),
        &diagnostics,
        .{ .ignore_unknown_fields = true },
    ) catch {
        std.debug.print("Failed to parse build.zig.zon\n", .{});
        return "unknown";
    };
    return manifest.version;
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const version = getVersion(b);

    const build_options = b.addOptions();
    build_options.addOption([]const u8, "version", version);
    const build_options_module = build_options.createModule();

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .strip = switch (optimize) {
            .Debug => false,
            else => true,
        },
    });
    exe_module.addImport("build_options", build_options_module);

    const exe = b.addExecutable(.{
        .name = "rio",
        .root_module = exe_module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the rio benchmark tool");
    run_step.dependOn(&run_cmd.step);

    const test_module = b.createModule(.{
        .root_source_file = b.path("src/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_module.addImport("build_options", build_options_module);

    const tests = b.addTest(.{
        .name = "rio-tests",
        .root_module = test_module,
    });

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
