#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "defs.h"

volatile static int started = 0;
uint32 dtb_uint(uint32 x) {
  return (((x) & 0xff000000u) >> 24) |
         (((x) & 0x00ff0000u) >> 8) |
         (((x) & 0x0000ff00u) << 8) |
         (((x) & 0x000000ffu) << 24);
}
uint32 str_len(uint8* s) {
  uint32 i = 0;
  while (*(s + i) != 0) {
    i += 1;
  }
  return i;
}
uint32 roundup(uint32 x) {
  uint32 rem = x % 4;
  return rem == 0 ? x : x - rem + 4;
}
uint8 *dtb_name(uint32 name_offset) {
  return (uint8*)_dtb + dtb_uint(_dtb->off_dt_strings) + name_offset;
}
void print_level_indent(uint32 level) {
  for (int i = 0; i < level; i++) {
    printf("  ");
  }
}
void print_prop_value(uint32 dt_offset, uint32 len) {
  uint8 *start = (uint8*)_dtb + dt_offset;
  for (int i = 0; i < len; i++) {
    if (i != 0) {
      printf(" ");
    }
    printf("%x", *(start + i));
  }
}

// start() jumps here in supervisor mode on all CPUs.
void
main()
{
  if(cpuid() == 0){
    consoleinit();
    printfinit();
    printf("\n");
    printf("xv6 kernel is booting\n");
    printf("\n");
    printf("_dtb: %p\n", _dtb);
    printf("magic: %p\n", dtb_uint(_dtb->magic));
    printf("struct: %p\n", dtb_uint(_dtb->off_dt_struct));
    uint32 dt_offset = dtb_uint(_dtb->off_dt_struct);
    uint32 dt_level = 0;
    while (1) {
      dt_offset = roundup(dt_offset);
      uint32 entry = dtb_uint(*(uint32*)((uint8*)_dtb + dt_offset));
      switch (entry) {
        case 0x1:
          dt_offset += 4;
          uint8 *name = (uint8*)_dtb + dt_offset;
          uint32 name_len = str_len(name);
          print_level_indent(dt_level);
          printf("> FDT_BEGIN_NODE, name(%d): \"%s\"\n", name_len, name);
          dt_level += 1;
          dt_offset += name_len + 1; // +1 for null terminator
          break;
        case 0x2:
          dt_level -= 1;
          print_level_indent(dt_level);
          printf("> FDT_END_NODE\n");
          dt_offset += 4;
          break;
        case 0x3:
          dt_offset += 4;
          uint32 len = dtb_uint(*(uint32*)((uint8*)_dtb + dt_offset));
          dt_offset += 4;
          uint32 name_offset = dtb_uint(*(uint32*)((uint8*)_dtb + dt_offset));
          print_level_indent(dt_level);
          printf("> FDT_PROP, len: %d, name(%d): %s, value: ", len, name_offset, dtb_name(name_offset));
          dt_offset += 4;
          print_prop_value(dt_offset, len);
          printf("\n");
          // data here, ignoring for now
          dt_offset += len;
          break;
        case 0x4:
          print_level_indent(dt_level);
          printf("> FDT_NOP\n");
          dt_offset += 4;
          break;
        case 0x9:
          print_level_indent(dt_level);
          printf("> FDT_END\n");
          dt_offset += 4;
          goto unrecognized_entry;
        default:
          printf("> Error: Unrecognized Entry: %p\n", entry);
          goto unrecognized_entry;
      }
    }
unrecognized_entry:
    kinit();         // physical page allocator
    kvminit();       // create kernel page table
    kvminithart();   // turn on paging
    procinit();      // process table
    trapinit();      // trap vectors
    trapinithart();  // install kernel trap vector
    plicinit();      // set up interrupt controller
    plicinithart();  // ask PLIC for device interrupts
    binit();         // buffer cache
    iinit();         // inode table
    fileinit();      // file table
    virtio_disk_init(); // emulated hard disk
    userinit();      // first user process
    __sync_synchronize();
    started = 1;
  } else {
    while(started == 0)
      ;
    __sync_synchronize();
    printf("hart %d starting\n", cpuid());
    kvminithart();    // turn on paging
    trapinithart();   // install kernel trap vector
    plicinithart();   // ask PLIC for device interrupts
  }

  scheduler();        
}
