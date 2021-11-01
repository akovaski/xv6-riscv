K=kernel
U=user

KERNEL_SRC = \
  $K/entry.S \
  $K/start.c \
  $K/console.c \
  $K/printf.c \
  $K/uart.c \
  $K/kalloc.c \
  $K/spinlock.c \
  $K/string.c \
  $K/main.c \
  $K/vm.c \
  $K/proc.c \
  $K/swtch.S \
  $K/trampoline.S \
  $K/trap.c \
  $K/syscall.c \
  $K/sysproc.c \
  $K/bio.c \
  $K/fs.c \
  $K/log.c \
  $K/sleeplock.c \
  $K/file.c \
  $K/pipe.c \
  $K/exec.c \
  $K/sysfile.c \
  $K/kernelvec.S \
  $K/plic.c \
  $K/virtio_disk.c

QEMU = qemu-system-riscv64

LDFLAGS = -z max-page-size=4096

$K/kernel: $(KERNEL_SRC) $K/kernel.ld build.zig
	#$(LD) $(LDFLAGS) -T $K/kernel.ld -o $K/kernel $(OBJS)
	zig build kernel/kernel

tags: $(KERNEL_SRC)
	etags $(KERNEL_SRC)

clean: 
	rm -f *.tex *.dvi *.idx *.aux *.log *.ind *.ilg \
	*/*.o */*.d */*.asm */*.sym \
	$K/kernel fs.img \
	mkfs/mkfs .gdbinit \
        $U/usys.S \
	user/_*
	rm -rf zig-out

# try to generate a unique GDB port
GDBPORT = $(shell expr `id -u` % 5000 + 25000)
# QEMU's gdb stub command line changed in 0.11
QEMUGDB = $(shell if $(QEMU) -help | grep -q '^-gdb'; \
	then echo "-gdb tcp::$(GDBPORT)"; \
	else echo "-s -p $(GDBPORT)"; fi)
ifndef CPUS
CPUS := 3
endif

QEMUOPTS = -machine virt -bios none -kernel $K/kernel -m 128M -smp $(CPUS) -nographic
QEMUOPTS += -drive file=fs.img,if=none,format=raw,id=x0
QEMUOPTS += -device virtio-blk-device,drive=x0,bus=virtio-mmio-bus.0

qemu:
	zig build qemu

.gdbinit: .gdbinit.tmpl-riscv
	sed "s/:1234/:$(GDBPORT)/" < $^ > $@

qemu-gdb: $K/kernel .gdbinit fs.img
	@echo "*** Now run 'gdb' in another window." 1>&2
	$(QEMU) $(QEMUOPTS) -S $(QEMUGDB)

