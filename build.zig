const std = @import("std");

// TODO: Automate this
const VERSION = @import("build.zig.zon").version;
const API = "3234";

const Config = struct {
    curses: bool,
    lua: bool,
    lpeg: bool,
    help: bool,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const config: Config = cfg: {
        const cfg_curses = b.option(bool, "enable-curses", "build with Curses terminal output (default: true)") orelse true;
        const cfg_lua = b.option(bool, "enable-lua", "build with Lua support (default: true)") orelse true;
        const cfg_lpeg = b.option(bool, "enable-lpeg-static", "build with LPeg static linking (default: <enable-lua>)");
        const cfg_help = b.option(bool, "enable-help", "build with built-in help texts (default: true)") orelse true;
        if (cfg_lpeg) |lpeg| if (lpeg and !cfg_lua) {
            std.log.err("need lua support for built-in lpeg", .{});
            return;
        };

        break :cfg .{
            .curses = cfg_curses,
            .lua = cfg_lua,
            .lpeg = cfg_lpeg orelse cfg_lua,
            .help = cfg_help,
        };
    };
    const share_prefix = b.fmt("{s}/share", .{b.install_prefix});

    const upstream_dep = b.dependency("upstream", .{});

    const cflags = getCFlags(b, config);
    const ldflags = getLdFlags(b);
    const cflags_std = concatFlags(b, &.{
        getCFlagsStd(b, target),
        &.{
            b.fmt("-DVERSION=\"{s}\"", .{VERSION}),
            b.fmt("-DVIS_API={s}", .{API}),
        },
    });
    const ldflags_std = getLdFlagsStd(b);
    const cflags_auto = getCFlagsAuto(b);
    const ldflags_auto = getLdFlagsAuto(b);

    const cflags_vis = concatFlags(b, &.{
        cflags_auto,
        // TODO: getCFlagsTermkey(b, config)
        // TODO: getCFlagsAcl(b, config)
        // TODO: getCFlagsSelinux(b, config)
        // TODO: getCFlagsTre(b, config)
        cflags_std,
        &.{
            "-DVIS_EXPORT=static",
            b.fmt("-DVIS_PATH=\"{s}/vis\"", .{share_prefix}),
        },
    });
    const ldflags_vis = concatFlags(b, &.{
        ldflags_auto,
        // TODO: getLdFlagsAcl(b, config)
        // TODO: getLdFlagsSelinux(b, config)
        // TODO: getLdFlagsTre(b, config)
        ldflags_std,
    });

    const vis_exe = b.addExecutable(.{
        .name = "vis",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    vis_exe.root_module.addCSourceFile(.{
        .file = upstream_dep.path("main.c"),
        .flags = concatFlags(b, &.{
            cflags,
            cflags_vis,
            cflags_extra,
            ldflags,
            ldflags_vis,
            ldflags_extra,
        }),
    });
    const config_header = b.addWriteFiles();
    _ = config_header.addCopyFile(upstream_dep.path("config.def.h"), "config.h");
    vis_exe.root_module.addIncludePath(config_header.getDirectory());
    b.installArtifact(vis_exe);

    // === CONFIG_CURSES === //
    if (config.curses) {
        vis_exe.root_module.addCMacro("CONFIG_CURSES", "1");
        if (b.systemIntegrationOption("curses", .{ .default = false })) {
            vis_exe.root_module.linkSystemLibrary("ncurses", .{});
        } else {
            if (b.lazyDependency("ncurses", .{
                .target = target,
                // NOTE: ncurses crashes the program at startup if optimized with ReleaseSafe or Debug
                .optimize = .ReleaseFast,
            })) |dep| {
                vis_exe.root_module.linkLibrary(dep.artifact("ncurses"));
            }
        }
    }

    // === CONFIG_LUA === //
    if (config.lua) {
        vis_exe.root_module.addCMacro("CONFIG_LUA", "1");
        if (b.systemIntegrationOption("lua", .{ .default = false })) {
            vis_exe.root_module.linkSystemLibrary("lua5.2", .{});
        } else {
            if (b.lazyDependency("zlua", .{
                .target = target,
                .optimize = optimize,
                .lang = .lua52,
            })) |dep| {
                vis_exe.root_module.linkLibrary(dep.artifact("lua"));
            }
        }
    }

    // === CONFIG_LPEG === //
    if (config.lpeg) {
        vis_exe.root_module.addCMacro("CONFIG_LPEG", "1");
        if (b.systemIntegrationOption("lpeg", .{ .default = false })) {
            vis_exe.root_module.linkSystemLibrary("lpeg", .{});
        } else {
            if (b.lazyDependency("lpeg", .{})) |dep| {
                vis_exe.root_module.addCSourceFiles(.{
                    .files = &.{
                        "lpcap.c",
                        "lpcode.c",
                        "lpcset.c",
                        "lpprint.c",
                        "lptree.c",
                        "lpvm.c",
                    },
                    .root = dep.path("."),
                });
            }
        }
    }

    const vis_menu_exe = b.addExecutable(.{
        .name = "vis-menu",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    vis_menu_exe.root_module.addCSourceFile(.{
        .file = upstream_dep.path("vis-menu.c"),
        .flags = concatFlags(b, &.{
            cflags,
            cflags_auto,
            cflags_std,
            cflags_extra,
            ldflags,
            ldflags_std,
            ldflags_auto,
            ldflags_extra,
            &.{"-Wno-unused-function"},
        }),
    });
    b.installArtifact(vis_menu_exe);

    const vis_digraph_exe = b.addExecutable(.{
        .name = "vis-digraph",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    vis_digraph_exe.root_module.addCSourceFile(.{
        .file = upstream_dep.path("vis-digraph.c"),
        .flags = concatFlags(b, &.{
            cflags,
            cflags_auto,
            cflags_std,
            cflags_extra,
            ldflags,
            ldflags_std,
            ldflags_auto,
            ldflags_extra,
        }),
    });
    b.installArtifact(vis_digraph_exe);

    // run step
    const run_step = b.step("run", "Run vis");
    const run_cmd = b.addRunArtifact(vis_exe);
    run_step.dependOn(&run_cmd.step);
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}

const Flags = []const []const u8;

// NOTE: Should these ever be set?
const cflags_extra: Flags = &.{};
const ldflags_extra: Flags = &.{};

fn concatFlags(b: *std.Build, flag_groups: []const Flags) Flags {
    var len: usize = 0;
    for (flag_groups) |f| len += f.len;
    const flags: [][]const u8 = b.graph.arena.alloc([]const u8, len) catch oom();
    var idx: usize = 0;
    for (flag_groups) |f| {
        defer idx += f.len;
        @memcpy(flags[idx .. idx + f.len], f);
    }
    return flags;
}

fn getCFlags(b: *std.Build, config: Config) Flags {
    const gpa = b.allocator;
    var flags: std.ArrayList([]const u8) = .empty;
    defer flags.deinit(gpa);
    flags.appendSlice(gpa, &.{
        "-Wall",
        "-pipe",
        "-Wno-initializer-overrides",
        "-Wno-override-init",
        "-ffunction-sections",
        "-fdata-sections",
        "-fPIE",
    }) catch oom();
    if (!config.help) flags.append(gpa, "-DCONFIG_HELP=0") catch oom();
    return flags.toOwnedSlice(gpa) catch oom();
}
fn getLdFlags(b: *std.Build) Flags {
    const gpa = b.allocator;
    var flags: std.ArrayList([]const u8) = .empty;
    defer flags.deinit(gpa);
    // TODO:? --static
    flags.appendSlice(gpa, &.{
        "-Wl,-z,now",
        "-Wl,-z,relro",
    }) catch oom();
    return flags.toOwnedSlice(gpa) catch oom();
}
fn getCFlagsStd(b: *std.Build, target: std.Build.ResolvedTarget) Flags {
    const gpa = b.allocator;
    var flags: std.ArrayList([]const u8) = .empty;
    defer flags.deinit(gpa);
    flags.appendSlice(gpa, &.{
        "-std=c99",
        "-DNDEBUG",
    }) catch oom();
    switch (target.result.os.tag) {
        .freebsd, .dragonfly => flags.appendSlice(gpa, &.{ "-D_BSD_SOURCE", "-D__BSD_VISIBLE=1" }) catch oom(),
        .netbsd => flags.append(gpa, "-D_NETBSD_SOURCE") catch oom(),
        .openbsd => flags.append(gpa, "-D_BSD_SOURCE") catch oom(),
        .macos => flags.append(gpa, "-D_DARWIN_C_SOURCE") catch oom(),
        // NOTE: AIX not supported by Zig
        // .aix => flags_std.append(gpa, "-D_ALL_SOURCE") catch oom(),
        else => {},
    }
    return flags.toOwnedSlice(gpa) catch oom();
}
fn getLdFlagsStd(b: *std.Build) Flags {
    _ = b;
    return &.{"-lc"};
}
fn getCFlagsAuto(b: *std.Build) Flags {
    _ = b;
    return &.{"-fstack-protector-all"};
}
fn getLdFlagsAuto(b: *std.Build) Flags {
    _ = b;
    return &.{ "-Wl,--gc-sections", "-pie" };
}
fn getCFlagsDebug(b: *std.Build) Flags {
    _ = b;
    return &.{
        "-U_FORTIFY_SOURCE",
        "-UNDEBUG",
        "-O0",
        "-g3",
        "-ggdb",
        "-Wall",
        "-Wextra",
        "-pedantic",
        "-Wno-missing-field-initializers",
        "-Wno-unused-parameter",
    };
}

fn oom() noreturn {
    @panic("OOM");
}
