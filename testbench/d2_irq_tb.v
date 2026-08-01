// d2_irq_tb.v - top level testbench: clock/reset generation, timeout,
// instantiates picorv32_wrapper (which holds the D2 IRQ stimulus)

module d2_irq_tb #(
	parameter AXI_TEST = 0,
	parameter VERBOSE = 0
);
	reg clk = 1;
	reg resetn = 0;
	wire trap;

	always #5 clk = ~clk;

	initial begin
		repeat (100) @(posedge clk);
		resetn <= 1;
	end

	initial begin
		if ($test$plusargs("vcd")) begin
			$dumpfile("d2_irq_tb_level.vcd");
			$dumpvars(0, d2_irq_tb_level);
		end
		repeat (300000) @(posedge clk);
		$display("TIMEOUT");
		$finish;
	end

	wire trace_valid;
	wire [35:0] trace_data;
	integer trace_file;

	initial begin
		if ($test$plusargs("trace")) begin
			trace_file = $fopen("testbench.trace", "w");
			repeat (10) @(posedge clk);
			while (!trap) begin
				@(posedge clk);
				if (trace_valid)
					$fwrite(trace_file, "%x\n", trace_data);
			end
			$fclose(trace_file);
			$display("Finished writing testbench.trace.");
		end
	end

	picorv32_wrapper_d2 #(
		.AXI_TEST (AXI_TEST),
		.VERBOSE  (VERBOSE)
	) top (
		.clk(clk),
		.resetn(resetn),
		.trap(trap),
		.trace_valid(trace_valid),
		.trace_data(trace_data)
	);
	always @(top.uut.picorv32_core.irq_active)
		$display("[MONITOR] irq_active=%b at cycle %0d, irq_pending=%h, irq_mask=%h",
			top.uut.picorv32_core.irq_active, $time/10,
			top.uut.picorv32_core.irq_pending, top.uut.picorv32_core.irq_mask);

	always @(top.uut.picorv32_core.irq_pending)
		$display("[PENDMON] irq_pending changed to %h at cycle %0d, top.irq=%b, irq_active=%b",
			top.uut.picorv32_core.irq_pending, $time/10,
			top.irq, top.uut.picorv32_core.irq_active);

endmodule
