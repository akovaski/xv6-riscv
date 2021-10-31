const std = @import("std");
const builtin = std.builtin;

pub fn build(b: *std.build.Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    //const mode = b.standardReleaseOptions();
    const target = std.zig.CrossTarget{
        .cpu_arch = .riscv64,
        .os_tag = .freestanding,
        .abi = .none,
    };
    const entry = b.step("entry", "build entry.o");
    //const build_entry = b.addObject("entry.o", null);
    var entry_args = &[_][]const u8{
        "clang-13", "--target=riscv64-unknown-elf",
        "-mno-relax", "-march=rv64imafdc", "-c",
        "-o", "kernel/entry.o", "kernel/entry.S",
    };
    const build_entry = b.addSystemCommand(entry_args);
    entry.dependOn(&build_entry.step);

    const vm = b.step("vm", "build vm.o");
    var vm_args = &[_][]const u8{
        "clang-13", "--target=riscv64-unknown-elf",
        "-mno-relax", "-march=rv64imafdc", "-c",
        "-Wall", "-Werror", "-O", "-fno-omit-frame-pointer",
        "-ggdb", "-MD", "-mcmodel=medany", "-ffreestanding",
        "-fno-common", "-nostdlib", "-I.", "-fno-stack-protector",
        "-o", "kernel/vm.o", "kernel/vm.c",
    };
    const build_vm = b.addSystemCommand(vm_args);
    vm.dependOn(&build_vm.step);

    const trap = b.step("trap", "build trap.o");
    var trap_args = &[_][]const u8{
        "clang-13", "--target=riscv64-unknown-elf",
        "-mno-relax", "-march=rv64imafdc", "-c",
        "-Wall", "-Werror", "-O", "-fno-omit-frame-pointer",
        "-ggdb", "-MD", "-mcmodel=medany", "-ffreestanding",
        "-fno-common", "-nostdlib", "-I.", "-fno-stack-protector",
        "-o", "kernel/trap.o", "kernel/trap.c",
    };
    const build_trap = b.addSystemCommand(trap_args);
    trap.dependOn(&build_trap.step);

    const exe = b.addExecutable("kernel", null);
    exe.step.dependOn(&build_entry.step);
    exe.step.dependOn(&build_vm.step);
    exe.step.dependOn(&build_trap.step);

    exe.setOutputDir("kernel");

    exe.setLinkerScriptPath(.{ .path = "kernel/kernel.ld" });
    const cflags = &[_][]const u8{
        "-Wall","-Werror","-Os","-fno-omit-frame-pointer","-ggdb","-MD",
        "-mcmodel=medany","-ffreestanding","-fno-common","-nostdlib","-mno-relax",
        "-I.","-fno-stack-protector","-fno-pie","-march=rv64imafdc","-mabi=lp64d"};
    exe.addObjectFile("kernel/entry.o");
    //exe.addAssemblyFile("kernel/entry.S");
    exe.addCSourceFile("kernel/start.c", cflags);
    exe.addCSourceFile("kernel/console.c", cflags);
    exe.addCSourceFile("kernel/printf.c", cflags);
    exe.addCSourceFile("kernel/uart.c", cflags);
    exe.addCSourceFile("kernel/kalloc.c", cflags);
    exe.addCSourceFile("kernel/spinlock.c", cflags);
    exe.addCSourceFile("kernel/string.c", cflags);
    exe.addCSourceFile("kernel/main.c", cflags);
    exe.addObjectFile("kernel/vm.o");
    exe.addCSourceFile("kernel/proc.c", cflags);
    exe.addAssemblyFile("kernel/swtch.S");
    exe.addAssemblyFile("kernel/trampoline.S");
    exe.addObjectFile("kernel/trap.o");
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
    exe.setBuildMode(.Debug); // other build modes currently don't properly compile C files
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
