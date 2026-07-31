// ai_engine_model.v — behavioral model, not synthesizable
// ASSUMPTION: real register map undefined in the doc; state this in the assumptions list

module ai_engine_model (
    input  wire        sck,
    input  wire        csb,
    input  wire        si,
    output reg         so,
    output reg         irq_status,

    input  wire        tb_never_respond,
    input  wire [15:0] tb_ack_delay_cycles,
    input  wire        tb_force_not_done
);

    reg [7:0] coeff_buffer [0:255]; // size TBD
    reg       init_done;
    reg       result_ready;
    reg [7:0] anomaly_result;

    task automatic receive_coefficients(input [7:0] stream [0:255]);
        integer i;
        begin
            for (i = 0; i < 256; i = i + 1)
                coeff_buffer[i] <= stream[i];
            if (!tb_never_respond)
                init_done <= 1; // interrupted transfer should NOT silently set this
        end
    endtask

    // ack-delay counter, irq_status timing

endmodule
