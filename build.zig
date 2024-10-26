const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    const util = b.addModule("util", .{
        .root_source_file = .{
            .src_path = .{
                .owner = b,
                .sub_path = "src/util/util.zig"
            }
        }
    });

    const game_zones = b.addModule("game_zones", .{
        .root_source_file = .{
            .src_path = .{
                .owner = b,
                .sub_path = "src/game_zones/game_zones.zig"
            }
        }
    });

    const parsing = b.addModule("parsing", .{
        .root_source_file = .{
            .src_path = .{
                .owner = b,
                .sub_path = "src/parsing/parsing.zig",
            }
        }
    });

    const game_runtime = b.addModule("game_runtime", .{
        .root_source_file = .{
            .src_path = .{
                .owner = b,
                .sub_path = "src/game_runtime/game_runtime.zig",
            }
        }
    });

    // add our dependent imports to parsing
    game_zones.addImport("util", util);

    parsing.addImport("util", util);
    parsing.addImport("game_zones", game_zones);

    game_runtime.addImport("util", util);
    game_runtime.addImport("game_zones", game_zones);
    game_runtime.addImport("parsing", parsing);

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "mage_duel_z",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("util", util);
    exe.root_module.addImport("game_zones", game_zones);
    exe.root_module.addImport("parsing", parsing);
    exe.root_module.addImport("game_runtime", game_runtime);

    const check_exe = b.addExecutable(.{
        .name = "mage_duel_z",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    check_exe.root_module.addImport("util", util);
    check_exe.root_module.addImport("game_zones", game_zones);
    check_exe.root_module.addImport("parsing", parsing);
    check_exe.root_module.addImport("game_runtime", game_runtime);

    // These two lines you might want to copy
    // (make sure to rename 'exe_check')
    const check = b.step("check", "Check if foo compiles");
    check.dependOn(&check_exe.step);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const tests = b.addTest(.{
        .root_source_file = b.path("src/test/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    tests.root_module.addImport("util", util);
    tests.root_module.addImport("game_zones", game_zones);
    tests.root_module.addImport("parsing", parsing);
    tests.root_module.addImport("game_runtime", game_runtime);

    const run_tests = b.addRunArtifact(tests);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_unit_tests.root_module.addImport("util", util);
    exe_unit_tests.root_module.addImport("game_zones", game_zones);
    exe_unit_tests.root_module.addImport("parsing", parsing);
    exe_unit_tests.root_module.addImport("game_runtime", game_runtime);

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_tests.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}
