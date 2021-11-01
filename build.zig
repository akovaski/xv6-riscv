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

    const kernel = b.step("kernel", "Build xv6 kernel");
    kernel.dependOn(&build_kernel.step);
    b.default_step = kernel;

    const build_mkfs = b.addExecutable("mkfs", null);
    build_mkfs.setOutputDir("mkfs");
    build_mkfs.addIncludeDir(".");
    build_mkfs.addCSourceFile("mkfs/mkfs.c", cflags);
    build_mkfs.setBuildMode(.Debug);
    build_mkfs.linkLibC();
    build_mkfs.setTarget(b.standardTargetOptions(.{}));

    const mkfs = b.step("mkfs", "Build mkfs executable");
    mkfs.dependOn(&build_mkfs.step);

    const build_cat = buildUserExec(b, target, mode, cflags, "cat", "cat.c");
    const build_echo = buildUserExec(b, target, mode, cflags, "echo", "echo.c");
    const build_forktest = buildUserExec(b, target, mode, cflags, "forktest", "forktest.c");
    const build_grep = buildUserExec(b, target, mode, cflags, "grep", "grep.c");
    //_init
    const build_kill = buildUserExec(b, target, mode, cflags, "kill", "kill.c");
    const build_ln = buildUserExec(b, target, mode, cflags, "ln", "ln.c");
    const build_ls = buildUserExec(b, target, mode, cflags, "ls", "ls.c");
    const build_mkdir = buildUserExec(b, target, mode, cflags, "mkdir", "mkdir.c");
    const build_rm = buildUserExec(b, target, mode, cflags, "rm", "rm.c");
    const build_sh = buildUserExec(b, target, mode, cflags, "sh", "sh.c");
    const build_stressfs = buildUserExec(b, target, mode, cflags, "stressfs", "stressfs.c");
    const build_usertests = buildUserExec(b, target, mode, cflags, "usertests", "usertests.c");
    const build_grind = buildUserExec(b, target, mode, cflags, "grind", "grind.c");
    const build_wc = buildUserExec(b, target, mode, cflags, "wc", "wc.c");
    const build_zombie = buildUserExec(b, target, mode, cflags, "zombie", "zombie.c");

    const UPROGS = [_][]const u8{
        //"user/_cat",
        //"user/_echo",
        //"user/_forktest",
        //"user/_grep",
        "user/_init",
        //"user/_kill",
        //"user/_ln",
        //"user/_ls",
        //"user/_mkdir",
        //"user/_rm",
        //"user/_sh",
        //"user/_stressfs",
        //"user/_usertests",
        //"user/_grind",
        //"user/_wc",
        //"user/_zombie",
    };
    var build_fs_img = build_mkfs.run();
    build_fs_img.addArgs(&[_][]const u8{ "fs.img", "README" });
    build_fs_img.addFileSourceArg(build_cat.getOutputSource());
    build_fs_img.addFileSourceArg(build_echo.getOutputSource());
    build_fs_img.addFileSourceArg(build_forktest.getOutputSource());
    build_fs_img.addFileSourceArg(build_grep.getOutputSource());
    build_fs_img.addFileSourceArg(build_kill.getOutputSource());
    build_fs_img.addFileSourceArg(build_ln.getOutputSource());
    build_fs_img.addFileSourceArg(build_ls.getOutputSource());
    build_fs_img.addFileSourceArg(build_mkdir.getOutputSource());
    build_fs_img.addFileSourceArg(build_rm.getOutputSource());
    build_fs_img.addFileSourceArg(build_sh.getOutputSource());
    build_fs_img.addFileSourceArg(build_stressfs.getOutputSource());
    build_fs_img.addFileSourceArg(build_usertests.getOutputSource());
    build_fs_img.addFileSourceArg(build_grind.getOutputSource());
    build_fs_img.addFileSourceArg(build_wc.getOutputSource());
    build_fs_img.addFileSourceArg(build_zombie.getOutputSource());
    build_fs_img.addArgs(&UPROGS);

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

pub fn buildUserExec(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, cflags: []const []const u8, comptime name: []const u8, comptime c_file: []const u8) *std.build.LibExeObjStep {
    const build_user_exec = b.addExecutable("_" ++ name, null);
    build_user_exec.setOutputDir("user");
    build_user_exec.setLinkerScriptPath(.{ .path = "user/user.ld" });
    build_user_exec.addIncludeDir(".");
    build_user_exec.addCSourceFile("user/" ++ c_file, cflags);
    build_user_exec.addObjectFile("user/ulib.o");
    build_user_exec.addObjectFile("user/usys.o");
    build_user_exec.addObjectFile("user/printf.o");
    build_user_exec.addObjectFile("user/umalloc.o");
    build_user_exec.setTarget(target);
    build_user_exec.target_abi = .lp64d;
    build_user_exec.code_model = .medium;
    build_user_exec.pie = false;
    build_user_exec.setBuildMode(mode);

    const user_exec = b.step(name, "Build xv6 " ++ c_file ++ " user executable");
    user_exec.dependOn(&build_user_exec.step);

    return build_user_exec;
}
