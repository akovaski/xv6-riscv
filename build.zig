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

    const exe = b.addExecutable("kernel", null);
    exe.setOutputDir("kernel");

    exe.setLinkerScriptPath(.{ .path = "kernel/kernel.ld" });
    const cflags = &[_][]const u8{
        "-Wall","-Werror","-fno-omit-frame-pointer","-ggdb","-MD",
        "-mcmodel=medany","-ffreestanding","-fno-common","-nostdlib","-mno-relax",
        "-I.","-fno-pie","-march=rv64imafdc","-mabi=lp64d"};
    exe.addAssemblyFile("kernel/entry.S");
    exe.addCSourceFile("kernel/start.c", cflags);
    exe.addCSourceFile("kernel/console.c", cflags);
    exe.addCSourceFile("kernel/printf.c", cflags);
    exe.addCSourceFile("kernel/uart.c", cflags);
    exe.addCSourceFile("kernel/kalloc.c", cflags);
    exe.addCSourceFile("kernel/spinlock.c", cflags);
    exe.addCSourceFile("kernel/string.c", cflags);
    exe.addCSourceFile("kernel/main.c", cflags);
    exe.addCSourceFile("kernel/vm.c", cflags);
    exe.addCSourceFile("kernel/proc.c", cflags);
    exe.addAssemblyFile("kernel/swtch.S");
    exe.addAssemblyFile("kernel/trampoline.S");
    exe.addCSourceFile("kernel/trap.c", cflags);
    exe.addCSourceFile("kernel/syscall.c", cflags);
    exe.addCSourceFile("kernel/sysproc.c", cflags);
    exe.addCSourceFile("kernel/bio.c", cflags);
    exe.addCSourceFile("kernel/fs.c", cflags);
    exe.addCSourceFile("kernel/log.c", cflags);
    exe.addCSourceFile("kernel/sleeplock.c", cflags);
    exe.addCSourceFile("kernel/file.c", cflags);
    exe.addCSourceFile("kernel/pipe.c", cflags);
    exe.addCSourceFile("kernel/exec.c", cflags);
    exe.addCSourceFile("kernel/sysfile.c", cflags);
    exe.addAssemblyFile("kernel/kernelvec.S");
    exe.addCSourceFile("kernel/plic.c", cflags);
    exe.addCSourceFile("kernel/virtio_disk.c", cflags);
    exe.setTarget(target);
    exe.setBuildMode(mode);
    exe.install();

    const qemu = b.step("qemu", "Run the OS in qemu");
    var qemu_args = &[_][]const u8{
        "qemu-system-x86_64",
        "-kernel",
        //exe.getOutputSource().getPath(b),
        "-curses",
    };
    const run_qemu = b.addSystemCommand(qemu_args);
    qemu.dependOn(&run_qemu.step);
    run_qemu.step.dependOn(&exe.step);
}
