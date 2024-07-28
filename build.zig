const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const exe = b.addExecutable(.{
        .name = "main",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .ReleaseFast,
    });

    const tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = .Debug
    });

    const run_tests = b.addRunArtifact(tests);

    const test_step = b.step("tests", "Run unit tests");
    test_step.dependOn(&run_tests.step);

    b.installArtifact(exe);
}
