// irq_test_harness.v — behavioral testbench harness, not synthesizable
// cpu_irq_active taps the DUT's internal irq_active (confirmed non-preemptive in picorv32.v)

module irq_test_harness (
    input  wire clk,
    output reg  irq_5,
    output reg  irq_6,
    output reg  irq_7,
    input  wire cpu_irq_active
);

    task automatic fire_simultaneous(input a, input b, input c);
        begin
            @(posedge clk);
            {irq_5, irq_6, irq_7} <= {a, b, c};
            @(posedge clk);
            {irq_5, irq_6, irq_7} <= 3'b000;
        end
    endtask

    // D2: fires target mid-handler; gap until CPU enters new handler is the measurement
    task automatic fire_mid_handler(input integer target_bit);
        begin
            wait (cpu_irq_active == 1);
            @(posedge clk);
            case (target_bit)
                5: irq_5 <= 1;
                6: irq_6 <= 1;
                7: irq_7 <= 1;
            endcase
            @(posedge clk);
            {irq_5, irq_6, irq_7} <= 3'b000;
        end
    endtask

    task automatic fire_rapid(input integer target_bit, input integer gap_cycles);
        integer j;
        begin
            fire_simultaneous(target_bit==5, target_bit==6, target_bit==7);
            for (j = 0; j < gap_cycles; j = j + 1)
                @(posedge clk);
            fire_simultaneous(target_bit==5, target_bit==6, target_bit==7);
        end
    endtask

endmodule
