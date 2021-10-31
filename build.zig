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

    const UPROGS = [_][]const u8{
        "user/_cat",
        "user/_echo",
        "user/_forktest",
        "user/_grep",
        "user/_init",
        "user/_kill",
        "user/_ln",
        "user/_ls",
        "user/_mkdir",
        "user/_rm",
        "user/_sh",
        "user/_stressfs",
        "user/_usertests",
        "user/_grind",
        "user/_wc",
        "user/_zombie",
    };
    var build_fs_img = build_mkfs.run();
    build_fs_img.addArgs(&[_][]const u8{ "fs.img", "README" } ++ UPROGS);
    build_fs_img.step.dependOn(&build_kernel.step);

    const fs_img = b.step("fs.img", "Create fs.img");
    fs_img.dependOn(&build_fs_img.step);

    const num_cpus = "3";
    var qemu_args = &[_][]const u8{
        "qemu-system-riscv64",
        "-machine","virt","-bios","none","-kernel","kernel/kernel","-m","128M","-smp",num_cpus,"-nographic",
        "-drive","file=fs.img,if=none,format=raw,id=x0",
        "-device","virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0"
    };
    const run_qemu = b.addSystemCommand(qemu_args);
    run_qemu.step.dependOn(&build_kernel.step);
    run_qemu.step.dependOn(&build_fs_img.step);

    const qemu = b.step("qemu", "Run the OS in qemu");
    qemu.dependOn(&run_qemu.step);
}
