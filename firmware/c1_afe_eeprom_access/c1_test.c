#include "firmware.h"

static unsigned int rdcycle(void)
{
    unsigned int cyc;
    __asm__ volatile ("rdcycle %0" : "=r"(cyc));
    return cyc;
}

static volatile unsigned int entry_cycle_afe = 0;
static volatile int c1_done = 0;

uint32_t *irq(uint32_t *regs, uint32_t irqs)
{
    if ((irqs & (1 << 5)) && !c1_done) {
        entry_cycle_afe = rdcycle();
        print_str("[C1] AFE serviced at cycle ");
        print_dec(entry_cycle_afe);
        print_str(" while foreground code was polling\n");
        c1_done = 1;
    }
    return regs;
}

void hello(void)
{
    // foreground poll loop, not inside an interrupt handler, unlike D2's Tx handler
    print_str("[C1] entering foreground poll loop at cycle ");
    print_dec(rdcycle());
    print_str("\n");

    while (!c1_done) { }

    print_str("C1 TEST COMPLETE\n");
    while (1) { }
}
