const std = @import("std");
const builtin = std.builtin;

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    //const mode = b.standardReleaseOptions();

    // Debug and ReleaseSafe don't seem to work well with xv6
    const mode = std.builtin.Mode.ReleaseSmall;

    const target = std.zig.CrossTarget{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    };

    const build_kernel = b.addExecutable("kernel", null);
    build_kernel.setOutputDir("kernel");

    build_kernel.setLinkerScriptPath(.{ .path = "kernel/kernel.ld" });
    const cflags = &[_][]const u8{ "-Wall", "-Werror" };
    build_kernel.addIncludeDir(".");
    build_kernel.addAssemblyFile("kernel/entry.S");
    build_kernel.addCSourceFile("kernel/start.c", cflags);
    build_kernel.addCSourceFile("kernel/console.c", cflags);
    build_kernel.addCSourceFile("kernel/printf.c", cflags);
    build_kernel.addCSourceFile("kernel/uart.c", cflags);
    build_kernel.addCSourceFile("kernel/kalloc.c", cflags);
    build_kernel.addCSourceFile("kernel/spinlock.c", cflags);
    build_kernel.addCSourceFile("kernel/string.c", cflags);
    build_kernel.addCSourceFile("kernel/main.c", cflags);
    build_kernel.addCSourceFile("kernel/vm.c", cflags);
    build_kernel.addCSourceFile("kernel/proc.c", cflags);
    build_kernel.addAssemblyFile("kernel/swtch.S");
    build_kernel.addAssemblyFile("kernel/trampoline.S");
    build_kernel.addCSourceFile("kernel/trap.c", cflags);
    build_kernel.addCSourceFile("kernel/syscall.c", cflags);
    build_kernel.addCSourceFile("kernel/sysproc.c", cflags);
    build_kernel.addCSourceFile("kernel/bio.c", cflags);
    build_kernel.addCSourceFile("kernel/fs.c", cflags);
    build_kernel.addCSourceFile("kernel/log.c", cflags);
    build_kernel.addCSourceFile("kernel/sleeplock.c", cflags);
    build_kernel.addCSourceFile("kernel/file.c", cflags);
    build_kernel.addCSourceFile("kernel/pipe.c", cflags);
    build_kernel.addCSourceFile("kernel/exec.c", cflags);
    build_kernel.addCSourceFile("kernel/sysfile.c", cflags);
    build_kernel.addAssemblyFile("kernel/kernelvec.S");
    build_kernel.addCSourceFile("kernel/plic.c", cflags);
    build_kernel.addCSourceFile("kernel/virtio_disk.c", cflags);
    build_kernel.setTarget(target);
    build_kernel.target_abi = .lp64d;
    build_kernel.code_model = .medium;
    build_kernel.pie = false;
    build_kernel.setBuildMode(mode);

    const kernel = b.step("kernel/kernel", "Build xv6 kernel AND .asm/.sym files");
    kernel.dependOn(&build_kernel.step);
    b.default_step = kernel;

    {
        const create_syms = createSym(b, build_kernel, "kernel/kernel");
        for (create_syms) |create_sym| {
            kernel.dependOn(&create_sym.step);
        }
    }

    const build_mkfs = b.addExecutable("mkfs", null);
    build_mkfs.setOutputDir("mkfs");
    build_mkfs.addIncludeDir(".");
    build_mkfs.addCSourceFile("mkfs/mkfs.c", cflags);
    build_mkfs.setBuildMode(.Debug);
    build_mkfs.linkLibC();

    const mkfs = b.step("mkfs", "Build mkfs executable");
    mkfs.dependOn(&build_mkfs.step);

    const build_ulib: *std.build.LibExeObjStep = buildUserLib(b, target, mode, cflags, "ulib");
    const build_usys = buildUsys(b, target, mode);
    const build_printf = buildUserLib(b, target, mode, cflags, "printf");
    const build_umalloc = buildUserLib(b, target, mode, cflags, "umalloc");
    const ulib: []*std.build.LibExeObjStep = &[_]*std.build.LibExeObjStep{ build_ulib, build_usys, build_printf, build_umalloc };

    var user_programs = [_]*std.build.LibExeObjStep{
        buildUserCExec(b, target, mode, cflags, "cat", ulib),
        buildUserCExec(b, target, mode, cflags, "echo", ulib),
        buildUserCExec(b, target, mode, cflags, "forktest", &[2]*std.build.LibExeObjStep{ build_ulib, build_usys }),
        buildUserCExec(b, target, mode, cflags, "grep", ulib),
        buildUserCExec(b, target, mode, cflags, "init", ulib),
        buildUserCExec(b, target, mode, cflags, "kill", ulib),
        buildUserCExec(b, target, mode, cflags, "ln", ulib),
        buildUserCExec(b, target, mode, cflags, "ls", ulib),
        buildUserCExec(b, target, mode, cflags, "mkdir", ulib),
        buildUserCExec(b, target, mode, cflags, "rm", ulib),
        buildUserCExec(b, target, mode, cflags, "sh", ulib),
        buildUserCExec(b, target, mode, cflags, "stressfs", ulib),
        //buildUserCExec(b, target, mode, cflags, "usertests", ulib),
        buildUserCExec(b, target, mode, cflags, "grind", ulib),
        buildUserCExec(b, target, mode, cflags, "wc", ulib),
        buildUserCExec(b, target, mode, cflags, "zombie", ulib),
        buildUserZigExec(b, target, mode, "my_fork", ulib),
        buildUserZigExec(b, target, mode, "my_call_echo", ulib),
        buildUserZigExec(b, target, mode, "my_cat", ulib),
        buildUserZigExec(b, target, mode, "sleep", ulib),
        buildUserZigExec(b, target, mode, "pingpong", ulib),
        //buildUserZigExec(b, target, mode, "primes", ulib),
        buildUserZigExec(b, target, mode, "find", ulib),
    };

    var build_fs_img = build_mkfs.run();
    build_fs_img.addArgs(&[_][]const u8{ "fs.img", "README" });
    const readme_src = std.build.FileSource{ .path = "README" };
    readme_src.addStepDependencies(&build_fs_img.step);
    for (user_programs) |program| {
        build_fs_img.addFileSourceArg(program.getOutputSource());
    }

    const fs_img = b.step("fs.img", "Create fs.img");
    fs_img.dependOn(&build_fs_img.step);

    const num_cpus = "3";
    var qemu_args = [_][]const u8{"qemu-system-riscv64"} ++
        [_][]const u8{ "-machine", "virt" } ++
        [_][]const u8{ "-bios", "none" } ++
        [_][]const u8{ "-kernel", "kernel/kernel" } ++
        [_][]const u8{ "-m", "128M" } ++
        [_][]const u8{ "-smp", num_cpus } ++
        [_][]const u8{"-nographic"} ++
        [_][]const u8{ "-drive", "file=fs.img,if=none,format=raw,id=x0" } ++
        [_][]const u8{ "-device", "virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0" };
    const run_qemu = b.addSystemCommand(&qemu_args);
    run_qemu.step.dependOn(&build_kernel.step);
    run_qemu.step.dependOn(&build_fs_img.step);

    const qemu = b.step("qemu", "Run the OS in qemu");
    qemu.dependOn(&run_qemu.step);
}

fn buildUserLib(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, cflags: []const []const u8, comptime name: []const u8) *std.build.LibExeObjStep {
    const build_user_lib = b.addObject(name, null);
    build_user_lib.setOutputDir("user");
    build_user_lib.addIncludeDir(".");
    build_user_lib.addCSourceFile("user/" ++ name ++ ".c", cflags);
    build_user_lib.setTarget(target);
    build_user_lib.target_abi = .lp64d;
    build_user_lib.code_model = .medium;
    build_user_lib.setBuildMode(mode);

    const user_exec = b.step("user/" ++ name ++ ".o", "Build xv6 " ++ name ++ " user library");
    user_exec.dependOn(&build_user_lib.step);

    return build_user_lib;
}
fn buildUsys(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode) *std.build.LibExeObjStep {
    const usys_pl_src = std.build.FileSource{ .path = "user/usys.pl" };
    const build_usys_s = b.addSystemCommand(&[_][]const u8{"perl"});
    build_usys_s.addFileSourceArg(usys_pl_src);
    build_usys_s.addArg("user/usys.S");

    const usys_s = b.step("user/usys.S", "Build usys.S file");
    usys_s.dependOn(&build_usys_s.step);

    const build_usys = b.addObject("usys", null);
    build_usys.setOutputDir("user");
    build_usys.addIncludeDir(".");
    build_usys.addAssemblyFile("user/usys.S");
    build_usys.setTarget(target);
    build_usys.target_abi = .lp64d;
    build_usys.code_model = .medium;
    build_usys.setBuildMode(mode);
    build_usys.step.dependOn(&build_usys_s.step);

    const usys = b.step("user/usys.o", "Build xv6 usys user library");
    usys.dependOn(&build_usys.step);

    return build_usys;
}

fn buildUserCExec(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, comptime cflags: []const []const u8, comptime name: []const u8, ulib: []*std.build.LibExeObjStep) *std.build.LibExeObjStep {
    return buildUserExec(b, target, mode, .{ .c = .{ .name = name, .cflags = cflags } }, ulib);
}
fn buildUserZigExec(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, comptime name: []const u8, ulib: []*std.build.LibExeObjStep) *std.build.LibExeObjStep {
    return buildUserExec(b, target, mode, .{ .zig = .{ .name = name } }, ulib);
}

const UserExecSource = union(enum) {
    c: struct {
        name: []const u8,
        cflags: []const []const u8,
    },
    zig: struct {
        name: []const u8,
    },

    fn name(self: UserExecSource) []const u8 {
        return switch (self) {
            .c => |c| c.name,
            .zig => |zig| zig.name,
        };
    }
};
fn buildUserExec(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, comptime source: UserExecSource, ulib: []*std.build.LibExeObjStep) *std.build.LibExeObjStep {
    const build_user_exec = switch (source) {
        .c => |c| blk: {
            const bld = b.addExecutable("_" ++ c.name, null);
            bld.addCSourceFile("user/" ++ c.name ++ ".c", c.cflags);
            break :blk bld;
        },
        .zig => |zig| b.addExecutable("_" ++ zig.name, "user/" ++ zig.name ++ ".zig"),
    };
    build_user_exec.setOutputDir("user");
    build_user_exec.setLinkerScriptPath(.{ .path = "user/user.ld" });
    build_user_exec.addIncludeDir(".");
    for (ulib) |lib| {
        build_user_exec.addObject(lib);
    }
    build_user_exec.setTarget(target);
    build_user_exec.target_abi = .lp64d;
    build_user_exec.code_model = .medium;
    build_user_exec.pie = false;
    build_user_exec.setBuildMode(mode);

    const user_exec = b.step("user/" ++ source.name(), "Build xv6 " ++ source.name() ++ " user executable AND .asm,.sym files");
    user_exec.dependOn(&build_user_exec.step);

    const create_syms = createSym(b, build_user_exec, "user/_" ++ source.name());
    for (create_syms) |create_sym| {
        user_exec.dependOn(&create_sym.step);
    }

    return build_user_exec;
}

fn createSym(b: *std.build.Builder, bin: *std.build.LibExeObjStep, comptime exec_path: []const u8) [2]*std.build.RunStep {
    const run_create_asm = b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "llvm-objdump-13 -S " ++ exec_path ++ " > " ++ exec_path ++ ".asm",
    });
    run_create_asm.step.dependOn(&bin.step);
    const run_create_sym = b.addSystemCommand(&[_][]const u8{
        "sh",
        "-c",
        "llvm-objdump-13 -t " ++ exec_path ++ " | sed '1,/SYMBOL TABLE/d; s/ .* / /; /^$$/d' > " ++ exec_path ++ ".sym",
    });
    run_create_sym.step.dependOn(&bin.step);

    return [_]*std.build.RunStep{ run_create_asm, run_create_sym };
}
