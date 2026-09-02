const std = @import("std");

const VERSION = @import("build.zig.zon").version;
const API = "3234"; // TODO: Automate this

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const upstream_dep = b.dependency("upstream", .{});

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
        // cflags
        .flags = cflags ++
            cflags_vis ++
            cflags_extra ++
            // ldflags
            ldflags ++
            ldflags_vis ++
            ldflags_extra,
    });
    const config_header = b.addWriteFiles();
    _ = config_header.addCopyFile(upstream_dep.path("config.def.h"), "config.h");
    vis_exe.root_module.addIncludePath(config_header.getDirectory());
    b.installArtifact(vis_exe);
}

const Flags = []const []const u8;

const cflags: Flags = &.{
    "-Wall",
    "-pipe",
    "-Wno-override-init",
    "-O2",
    "-ffunction-sections",
    "-fdata-sections",
    "-fPIE",
};

const ldflags: Flags = &.{
    "--static",
    "-Wl,-z,now",
    "-Wl,-z,relro",
};

const cflags_std: Flags = &.{
    "-std=c99",
    "-DNDEBUG",
    // TODO: addCMacro?
    "-DVERSION=\"" ++ VERSION ++ "\"",
    "-DVIS_API=" ++ API,
};
const ldflags_std: Flags = &.{
    // NOTE: Just -lc, which is covered by module.linkLibC()
};

const cflags_auto: Flags = &.{"-fstack-protector-all"};
const ldflags_auto: Flags = &.{ "-Wl,--gc-sections", "-pie" };

const cflags_debug: Flags = &.{
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

const cflags_termkey: Flags = &.{
    "-DTERMINFO=\"/usr/share/terminfo\"",
    "-DTERMINFO_DIRS=\"/etc/terminfo:/usr/share/terminfo\"",
};

const cflags_curses: Flags = &.{};
const ldflags_curses: Flags = &.{};
const cflags_tre: Flags = &.{};
const ldflags_tre: Flags = &.{};
const cflags_lua: Flags = &.{};
const ldflags_lua: Flags = &.{};
const cflags_lpeg: Flags = &.{};
const ldflags_lpeg: Flags = &.{};
const cflags_acl: Flags = &.{};
const ldflags_acl: Flags = &.{};
const cflags_selinux: Flags = &.{};
const ldflags_selinux: Flags = &.{};

const cflags_vis: Flags =
    cflags_auto ++
    cflags_termkey ++
    cflags_curses ++
    cflags_acl ++
    cflags_selinux ++
    cflags_tre ++
    cflags_lua ++
    cflags_lpeg ++
    cflags_std ++
    @as(Flags, &.{"-DVIS_EXPORT=static"});

const ldflags_vis: Flags =
    ldflags_auto ++
    ldflags_curses ++
    ldflags_acl ++
    ldflags_selinux ++
    ldflags_tre ++
    ldflags_lua ++
    ldflags_lpeg ++
    ldflags_std;

const cflags_extra: Flags = &.{};
const ldflags_extra: Flags = &.{};
