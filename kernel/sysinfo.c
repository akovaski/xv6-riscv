#include "types.h"
#include "param.h"
#include "riscv.h"
#include "spinlock.h"
#include "proc.h"
#include "defs.h"
#include "sysinfo.h"

int systeminfo(uint64 info_addr)
{
  struct proc *p = myproc();
  struct sysinfo info;

  info.freemem = freememcount();
  info.nproc = nproc();
  if(copyout(p->pagetable, info_addr, (char *)&info, sizeof(info)) < 0)
    return -1;
  return 0;
}