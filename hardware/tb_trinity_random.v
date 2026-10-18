`timescale 1ns/1ps

module tb_trinity_pipe_decoder;
    reg clk;
    reg rst_n;
    reg [1:0] trit_in;

    wire [3:0] data_out;
    wire data_ready;
    wire frame_error;

    // Statistical counters
    integer i;
    integer passed_packets = 0;
    integer total_packets  = 100; 
    reg [3:0] expected_value;
    
    reg [1:0] encoded_trits [0:4];
    integer trit_length;
    integer t;

    // Unit Under Test (UUT)
    trinity_pipe_decoder uut (
        .clk(clk),
        .rst_n(rst_n),
        .trit_in(trit_in),
        .data_out(data_out),
        .data_ready(data_ready),
        .frame_error(frame_error)
    );

    // 100 MHz Clock Generator
    always #5 clk = ~clk;

    initial begin
        $dumpfile("trinity_random_dump.vcd");
        $dumpvars(0, tb_trinity_pipe_decoder);

        // --- Step 1: Hardware Reset (Cold Start) ---
        clk = 0;
        rst_n = 0;
        trit_in = 2'b11; // Start at proper physical BUS_IDLE state
        #15;
        rst_n = 1;
        #5; 

        $display("================================================================");
        $display("   STARTING CONSTRAINED RANDOM VERIFICATION (100 PACKETS)       ");
        $display("================================================================");

        // --- Step 2: Random Payload Loop ---
        for (i = 0; i < total_packets; i = i + 1) begin
            
            expected_value = $unsigned($random) % 16;
            
            case (expected_value)
                4'd0:  begin encoded_trits[0] = 2'b10; trit_length = 1; end
                4'd1:  begin encoded_trits[0] = 2'b00; encoded_trits[1] = 2'b10; trit_length = 2; end
                4'd2:  begin encoded_trits[0] = 2'b01; encoded_trits[1] = 2'b10; trit_length = 2; end
                4'd3:  begin encoded_trits[0] = 2'b00; encoded_trits[1] = 2'b00; encoded_trits[2] = 2'b10; trit_length = 3; end
                4'd4:  begin encoded_trits[0] = 2'b00; encoded_trits[1] = 2'b01; encoded_trits[2] = 2'b10; trit_length = 3; end
                4'd5:  begin encoded_trits[0] = 2'b01; encoded_trits[1] = 2'b00; encoded_trits[2] = 2'b10; trit_length = 3; end
                4'd6:  begin encoded_trits[0] = 2'b01; encoded_trits[1] = 2'b01; encoded_trits[2] = 2'b10; trit_length = 3; end
                4'd7:  begin encoded_trits[0] = 2'b00; encoded_trits[1] = 2'b00; encoded_trits[2] = 2'b00; encoded_trits[3] = 2'b10; trit_length = 4; end
                4'd8:  begin encoded_trits[0] = 2'b00; encoded_trits[1] = 2'b00; encoded_trits[2] = 2'b01; encoded_trits[3] = 2'b10; trit_length = 4; end
                4'd9:  begin encoded_trits[0] = 2'b00; encoded_trits[1] = 2'b01; encoded_trits[2] = 2'b00; encoded_trits[3] = 2'b10; trit_length = 4; end
                4'd10: begin encoded_trits[0] = 2'b00; encoded_trits[1] = 2'b01; encoded_trits[2] = 2'b01; encoded_trits[3] = 2'b10; trit_length = 4; end
                4'd11: begin encoded_trits[0] = 2'b01; encoded_trits[1] = 2'b00; encoded_trits[2] = 2'b00; encoded_trits[3] = 2'b10; trit_length = 4; end
                4'd12: begin encoded_trits[0] = 2'b01; encoded_trits[1] = 2'b00; encoded_trits[2] = 2'b01; encoded_trits[3] = 2'b10; trit_length = 4; end
                4'd13: begin encoded_trits[0] = 2'b01; encoded_trits[1] = 2'b01; encoded_trits[2] = 2'b00; encoded_trits[3] = 2'b10; trit_length = 4; end
                4'd14: begin encoded_trits[0] = 2'b01; encoded_trits[1] = 2'b01; encoded_trits[2] = 2'b01; encoded_trits[3] = 2'b10; trit_length = 4; end
                4'd15: begin encoded_trits[0] = 2'b00; encoded_trits[1] = 2'b00; encoded_trits[2] = 2'b00; encoded_trits[3] = 2'b00; encoded_trits[4] = 2'b10; trit_length = 5; end
            endcase

            // Feed trits into decoder step-by-step
            for (t = 0; t < trit_length; t = t + 1) begin
                trit_in = encoded_trits[t];
                #10;
            end

            // --- ONLINE CHECKING BLOCK ---
            #5; // Step past positive clock edge to capture stable RTL outputs
            if (data_ready) begin
                if (data_out === expected_value) begin
                    $display("[PASSED] Packet %3d | Decoded: %2d | Expected: %2d", i+1, data_out, expected_value);
                    passed_packets = passed_packets + 1;
                end else begin
                    $display("[CRITICAL ERROR] Packet %3d | Decoded: %2d | Expected: %2d <-- MISMATCH!", i+1, data_out, expected_value);
                    $finish;
                end
            end else begin
                $display("[CRITICAL ERROR] Packet %3d | Decoder missed data_ready strobe!", i+1);
                $finish;
            end
            
            #5; // Complete the current clock cycle

            // Go back to physical BUS_IDLE state during jitter delay periods
            trit_in = 2'b11; 
            #(($unsigned($random) % 3) * 10);
        end

        // --- Summary Report ---
        $display("================================================================");
        $display("                     FINAL VERIFICATION REPORT                  ");
        $display("================================================================");
        $display("  Total Generated Random Packets: %d", total_packets);
        $display("  Successfully Decoded Packets  : %d", passed_packets);
        if (passed_packets == total_packets) begin
            $display("  TEST STATUS: [SUCCESSFULLY PASSED (100%% ACCURACY)]");
        end else begin
            $display("  TEST STATUS: [DECODING FAILURE DETECTED]");
        end
        $display("================================================================");
        
        $finish;
    end

endmodule
