#include "firmware.h"

static volatile int d1_done = 0;

uint32_t *irq(uint32_t *regs, uint32_t irqs)
{
    // bit5=AFE, bit6=AI Engine; bit7 clear confirms an isolated D1 hit
    if ((irqs & (1 << 5)) && (irqs & (1 << 6)) && !(irqs & (1 << 7))) {
        print_str("[D1] AFE and AI Engine both pending in same entry, irqs=0x");
        print_hex(irqs, 8);
        print_str(" - collision handled, servicing AFE first\n");
        d1_done = 1;
    }
    return regs;
}

void hello(void)
{
    while (!d1_done) { }
    print_str("D1 TEST COMPLETE\n");
    while (1) { } 
}
