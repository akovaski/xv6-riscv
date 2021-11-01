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

    const build_ulib: *std.build.LibExeObjStep = buildUserLib(b, target, mode, cflags, "ulib");
    const build_usys = buildUsys(b, target, mode);
    const build_printf = buildUserLib(b, target, mode, cflags, "printf");
    const build_umalloc = buildUserLib(b, target, mode, cflags, "umalloc");
    const ulib: []*std.build.LibExeObjStep = &[_]*std.build.LibExeObjStep{ build_ulib, build_usys, build_printf, build_umalloc };

    var build_cat = buildUserExec(b, target, mode, cflags, "cat", ulib);
    build_cat.step.dependOn(&build_ulib.step);
    build_cat.step.dependOn(&build_usys.step);
    build_cat.step.dependOn(&build_printf.step);
    build_cat.step.dependOn(&build_umalloc.step);
    const build_echo = buildUserExec(b, target, mode, cflags, "echo", ulib);
    const build_forktest = buildUserExec(b, target, mode, cflags, "forktest", &[2]*std.build.LibExeObjStep{ build_ulib, build_usys });
    const build_grep = buildUserExec(b, target, mode, cflags, "grep", ulib);
    const build_init = buildUserExec(b, target, mode, cflags, "init", ulib);
    const build_kill = buildUserExec(b, target, mode, cflags, "kill", ulib);
    const build_ln = buildUserExec(b, target, mode, cflags, "ln", ulib);
    const build_ls = buildUserExec(b, target, mode, cflags, "ls", ulib);
    const build_mkdir = buildUserExec(b, target, mode, cflags, "mkdir", ulib);
    const build_rm = buildUserExec(b, target, mode, cflags, "rm", ulib);
    const build_sh = buildUserExec(b, target, mode, cflags, "sh", ulib);
    const build_stressfs = buildUserExec(b, target, mode, cflags, "stressfs", ulib);
    const build_usertests = buildUserExec(b, target, mode, cflags, "usertests", ulib);
    const build_grind = buildUserExec(b, target, mode, cflags, "grind", ulib);
    const build_wc = buildUserExec(b, target, mode, cflags, "wc", ulib);
    const build_zombie = buildUserExec(b, target, mode, cflags, "zombie", ulib);

    var build_fs_img = build_mkfs.run();
    build_fs_img.addArgs(&[_][]const u8{ "fs.img", "README" });
    const readme_src = std.build.FileSource{ .path = "README" };
    readme_src.addStepDependencies(&build_fs_img.step);
    build_fs_img.addFileSourceArg(build_cat.getOutputSource());
    build_fs_img.addFileSourceArg(build_echo.getOutputSource());
    build_fs_img.addFileSourceArg(build_forktest.getOutputSource());
    build_fs_img.addFileSourceArg(build_grep.getOutputSource());
    build_fs_img.addFileSourceArg(build_init.getOutputSource());
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

    const user_exec = b.step(name, "Build xv6 " ++ name ++ " user library");
    user_exec.dependOn(&build_user_lib.step);

    return build_user_lib;
}
fn buildUsys(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode) *std.build.LibExeObjStep {
    const usys_pl_src = std.build.FileSource{ .path = "user/usys.pl" };
    const build_usys_s = b.addSystemCommand(&[_][]const u8{"perl"});
    build_usys_s.addFileSourceArg(usys_pl_src);
    build_usys_s.addArg("user/usys.S");

    const usys_s = b.step("usys.S", "Build usys.S file");
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

    const usys = b.step("usys", "Build xv6 usys user library");
    usys.dependOn(&build_usys.step);

    return build_usys;
}

fn buildUserExec(b: *std.build.Builder, target: std.zig.CrossTarget, mode: std.builtin.Mode, cflags: []const []const u8, comptime name: []const u8, ulib: []*std.build.LibExeObjStep) *std.build.LibExeObjStep {
    const build_user_exec = b.addExecutable("_" ++ name, null);
    build_user_exec.setOutputDir("user");
    build_user_exec.setLinkerScriptPath(.{ .path = "user/user.ld" });
    build_user_exec.addIncludeDir(".");
    build_user_exec.addCSourceFile("user/" ++ name ++ ".c", cflags);
    for (ulib) |lib| {
        build_user_exec.addObject(lib);
    }
    build_user_exec.setTarget(target);
    build_user_exec.target_abi = .lp64d;
    build_user_exec.code_model = .medium;
    build_user_exec.pie = false;
    build_user_exec.setBuildMode(mode);

    const user_exec = b.step(name, "Build xv6 " ++ name ++ " user executable");
    user_exec.dependOn(&build_user_exec.step);

    return build_user_exec;
}
