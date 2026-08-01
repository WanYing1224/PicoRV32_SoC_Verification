#include "firmware.h"

static unsigned int rdcycle(void)
{
    unsigned int cyc;
    __asm__ volatile ("rdcycle %0" : "=r"(cyc));
    return cyc;
}

static volatile unsigned int entry_cycle_tx = 0;
static volatile unsigned int entry_cycle_afe = 0;
static volatile int d2_done = 0;

uint32_t *irq(uint32_t *regs, uint32_t irqs)
{
    print_str("[DEBUG] entry, irqs=0x");
    print_hex(irqs, 8);
    print_str(", cycle=");
    print_dec(rdcycle());
    print_str("\n");

    // bit7 = Wireless Tx, simulates a handler that takes real time to run
    if ((irqs & (1 << 7)) && !(irqs & (1 << 5))) {
        entry_cycle_tx = rdcycle();
        print_str("[D2] Wireless Tx handler entered at cycle ");
        print_dec(entry_cycle_tx);
        print_str("\n");
        for (volatile int i = 0; i < 3000; i++) { }   // simulated handler work
        print_str("[DEBUG] Tx busy loop finished, cycle=");
        print_dec(rdcycle());
        print_str("\n");
    }

    // bit5 = AFE, arriving here proves it waited for retirq from the Tx
    // handler above, not hardware preemption
    if ((irqs & (1 << 5)) && !(irqs & (1 << 7)) && !d2_done) {
        entry_cycle_afe = rdcycle();
        print_str("[D2] AFE serviced at cycle ");
        print_dec(entry_cycle_afe);
        print_str(", delay since Tx entry ");
        print_dec(entry_cycle_afe - entry_cycle_tx);
        print_str(" cycles\n");
        d2_done = 1;
    }

    return regs;
}

void hello(void)
{
    while (!d2_done) { }
    print_str("D2 TEST COMPLETE\n");
    while (1) { }   // ebreak does not halt with CATCH_ILLINSN=1, see D1 notes
}
