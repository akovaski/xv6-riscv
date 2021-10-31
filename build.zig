const std = @import("std");
const builtin = std.builtin;

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();
    const target = std.zig.CrossTarget{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    };
    const exe = b.addExecutable("kernel", null);
    exe.setOutputDir("kernel");

    exe.setLinkerScriptPath(.{ .path = "kernel/kernel.ld" });
    exe.addObjectFile("kernel/entry.o");
    exe.addObjectFile("kernel/start.o");
    exe.addObjectFile("kernel/console.o");
    exe.addObjectFile("kernel/printf.o");
    exe.addObjectFile("kernel/uart.o");
    exe.addObjectFile("kernel/kalloc.o");
    exe.addObjectFile("kernel/spinlock.o");
    exe.addObjectFile("kernel/string.o");
    exe.addObjectFile("kernel/main.o");
    exe.addObjectFile("kernel/vm.o");
    exe.addObjectFile("kernel/proc.o");
    exe.addObjectFile("kernel/swtch.o");
    exe.addObjectFile("kernel/trampoline.o");
    exe.addObjectFile("kernel/trap.o");
    exe.addObjectFile("kernel/syscall.o");
    exe.addObjectFile("kernel/sysproc.o");
    exe.addObjectFile("kernel/bio.o");
    exe.addObjectFile("kernel/fs.o");
    exe.addObjectFile("kernel/log.o");
    exe.addObjectFile("kernel/sleeplock.o");
    exe.addObjectFile("kernel/file.o");
    exe.addObjectFile("kernel/pipe.o");
    exe.addObjectFile("kernel/exec.o");
    exe.addObjectFile("kernel/sysfile.o");
    exe.addObjectFile("kernel/kernelvec.o");
    exe.addObjectFile("kernel/plic.o");
    exe.addObjectFile("kernel/virtio_disk.o");
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
