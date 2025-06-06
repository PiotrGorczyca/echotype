const std = @import("std");

pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native.
    const target = b.standardTargetOptions(.{});

    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const optimize = b.standardOptimizeOption(.{});

    // Create modules for reusable components
    const hotkey_module = b.addModule("hotkey", .{
        .root_source_file = b.path("src/hotkey.zig"),
    });

    const audio_module = b.addModule("audio", .{
        .root_source_file = b.path("src/audio.zig"),
    });

    const visualizer_module = b.addModule("visualizer", .{
        .root_source_file = b.path("src/visualizer.zig"),
    });

    const portaudio_bindings_module = b.addModule("portaudio_bindings", .{
        .root_source_file = b.path("src/portaudio_bindings.zig"),
    });

    const wav_writer_module = b.addModule("wav_writer", .{
        .root_source_file = b.path("src/wav_writer.zig"),
    });

    const x11_bindings_module = b.addModule("x11_bindings", .{
        .root_source_file = b.path("src/x11_bindings.zig"),
    });

    // Set up module dependencies
    audio_module.addImport("portaudio_bindings", portaudio_bindings_module);
    audio_module.addImport("wav_writer", wav_writer_module);
    hotkey_module.addImport("x11_bindings", x11_bindings_module);
    visualizer_module.addImport("x11_bindings", x11_bindings_module);

    const exe = b.addExecutable(.{
        .name = "echotype",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Link system libraries
    exe.linkSystemLibrary("X11");
    exe.linkSystemLibrary("Xtst");
    exe.linkSystemLibrary("Xfixes");
    exe.linkSystemLibrary("Xrender");
    exe.linkSystemLibrary("portaudio"); // PortAudio (cross-platform)
    exe.linkSystemLibrary("c");

    // Install the executable
    b.installArtifact(exe);

    // Create a run step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    // Allow running with arguments
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Add hotkey test executable
    const hotkey_test_exe = b.addExecutable(.{
        .name = "hotkey_test",
        .root_source_file = b.path("src/tests/hotkey_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add module imports for hotkey test
    hotkey_test_exe.root_module.addImport("hotkey", hotkey_module);

    // Link same libraries for test
    hotkey_test_exe.linkSystemLibrary("X11");
    hotkey_test_exe.linkSystemLibrary("Xtst");
    hotkey_test_exe.linkSystemLibrary("Xfixes");
    hotkey_test_exe.linkSystemLibrary("Xrender");
    hotkey_test_exe.linkSystemLibrary("c");

    // Install the test executable
    b.installArtifact(hotkey_test_exe);

    // Create a run step for hotkey test
    const run_hotkey_test_cmd = b.addRunArtifact(hotkey_test_exe);
    run_hotkey_test_cmd.step.dependOn(b.getInstallStep());

    const run_hotkey_test_step = b.step("test-hotkey", "Run hotkey detection test");
    run_hotkey_test_step.dependOn(&run_hotkey_test_cmd.step);

    // Add audio test executable
    const audio_test_exe = b.addExecutable(.{
        .name = "audio_test",
        .root_source_file = b.path("src/tests/audio_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add module imports for audio test
    audio_test_exe.root_module.addImport("audio", audio_module);

    // Link same libraries for audio test
    audio_test_exe.linkSystemLibrary("X11");
    audio_test_exe.linkSystemLibrary("Xtst");
    audio_test_exe.linkSystemLibrary("Xfixes");
    audio_test_exe.linkSystemLibrary("Xrender");
    audio_test_exe.linkSystemLibrary("portaudio");
    audio_test_exe.linkSystemLibrary("c");

    // Install the audio test executable
    b.installArtifact(audio_test_exe);

    // Create a run step for audio test
    const run_audio_test_cmd = b.addRunArtifact(audio_test_exe);
    run_audio_test_cmd.step.dependOn(b.getInstallStep());

    const run_audio_test_step = b.step("test-audio", "Run audio recording test");
    run_audio_test_step.dependOn(&run_audio_test_cmd.step);

    // Add visualizer test executable
    const visualizer_test_exe = b.addExecutable(.{
        .name = "visualizer_test",
        .root_source_file = b.path("src/tests/visualizer_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add module imports for visualizer test
    visualizer_test_exe.root_module.addImport("visualizer", visualizer_module);

    // Link same libraries for visualizer test
    visualizer_test_exe.linkSystemLibrary("X11");
    visualizer_test_exe.linkSystemLibrary("Xtst");
    visualizer_test_exe.linkSystemLibrary("Xfixes");
    visualizer_test_exe.linkSystemLibrary("Xrender");
    visualizer_test_exe.linkSystemLibrary("c");

    // Install the visualizer test executable
    b.installArtifact(visualizer_test_exe);

    // Create a run step for visualizer test
    const run_visualizer_test_cmd = b.addRunArtifact(visualizer_test_exe);
    run_visualizer_test_cmd.step.dependOn(b.getInstallStep());

    const run_visualizer_test_step = b.step("test-visualizer", "Run visualizer test");
    run_visualizer_test_step.dependOn(&run_visualizer_test_cmd.step);

    // Add cursor following test executable
    const follow_test_exe = b.addExecutable(.{
        .name = "visualizer_follow_test",
        .root_source_file = b.path("src/tests/visualizer_follow_test.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add module imports for follow test
    follow_test_exe.root_module.addImport("visualizer", visualizer_module);

    // Link same libraries for follow test
    follow_test_exe.linkSystemLibrary("X11");
    follow_test_exe.linkSystemLibrary("Xtst");
    follow_test_exe.linkSystemLibrary("Xfixes");
    follow_test_exe.linkSystemLibrary("Xrender");
    follow_test_exe.linkSystemLibrary("c");

    // Install the follow test executable
    b.installArtifact(follow_test_exe);

    // Create a run step for follow test
    const run_follow_test_cmd = b.addRunArtifact(follow_test_exe);
    run_follow_test_cmd.step.dependOn(b.getInstallStep());

    const run_follow_test_step = b.step("test-follow", "Run cursor following test");
    run_follow_test_step.dependOn(&run_follow_test_cmd.step);

    // Create test step
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
