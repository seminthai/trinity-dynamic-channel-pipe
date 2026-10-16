`timescale 1ns/1ps

module tb_trinity_pipe_decoder;
    reg clk;
    reg rst_n;
    reg [1:0] trit_in;

    wire [3:0] data_out;
    wire data_ready;
    wire frame_error;

    // Instantiate Unit Under Test (UUT)
    trinity_pipe_decoder uut (
        .clk(clk),
        .rst_n(rst_n),
        .trit_in(trit_in),
        .data_out(data_out),
        .data_ready(data_ready),
        .frame_error(frame_error)
    );

    // Bus clock generator (Period: 10 ns -> 100 MHz reference frequency)
    always #5 clk = ~clk;

    initial begin
        // Waveform dump directives for GTKWave/EPWave diagnostics
        $dumpfile("trinity_decoder_dump.vcd");
        $dumpvars(0, tb_trinity_pipe_decoder);

        // --- STEP 0: System Initialization (Hardware Cold Start) ---
        clk = 0;
        rst_n = 0;
        trit_in = 2'b00; // TRIT_0
        #15;
        rst_n = 1;       // Release hardware reset, channel goes active
        #5;

        // --- TEST 1: Transmission of Value 0 (Code: Z) ---
        // Expected outcome: data_out = 0, data_ready strobes for 1 clk cycle
        trit_in = 2'b10; // TRIT_Z
        #10;

        // --- TEST 2: Transmission of Value 4 (Code: 0 -> 1 -> Z) ---
        // Expected outcome: data_out = 4, data_ready strobes for 1 clk cycle
        trit_in = 2'b00; #10; // TRIT_0
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b10; #10; // TRIT_Z
        
        // --- TEST 3: Transmission of Value 6 (Code: 1 -> 1 -> Z) ---
        // Verification of boundary condition for 2-bit prefix window
        // Expected outcome: data_out = 6, data_ready strobes for 1 clk cycle
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b10; #10; // TRIT_Z

        // --- TEST 4: Transmission of Value 14 (Code: 1 -> 1 -> 1 -> Z) ---
        // Verification of maximum 3-bit prefix tree saturation
        // Expected outcome: data_out = 14, data_ready strobes for 1 clk cycle
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b10; #10; // TRIT_Z

        // --- TEST 5: Transmission of Value 15 (Code: 0 -> 0 -> 0 -> 0 -> Z) ---
        // Worst-Case Dilation profile check (5 clock cycles per single nibble)
        // Expected outcome: data_out = 15, data_ready strobes for 1 clk cycle
        trit_in = 2'b00; #10; // TRIT_0
        trit_in = 2'b00; #10; // TRIT_0
        trit_in = 2'b00; #10; // TRIT_0
        trit_in = 2'b00; #10; // TRIT_0
        trit_in = 2'b10; #10; // TRIT_Z
        
        // --- TEST 6: Hardware Watchdog Validation (Stuck line / Channel short circuit) ---
        // Injecting an overflowing continuous data stream without terminal Z delimiters
        trit_in = 2'b01; #10; // 1st bit accumulated (bit_count = 1)
        trit_in = 2'b01; #10; // 2nd bit accumulated (bit_count = 2)
        trit_in = 2'b01; #10; // 3rd bit accumulated (bit_count = 3)
        trit_in = 2'b01; #10; // 4th bit accumulated (bit_count = 4)
        trit_in = 2'b01; #10; // 5th continuous bit error! Expected: frame_error = 1
        trit_in = 2'b01; #10; // Line keeps flooding with noise
        
        // --- TEST 7: Self-Synchronization & Fault Isolation Verification ---
        // Arrival of a clean physical Z marker must asynchronously drop the error state
        // and instantly re-align the bus state machine without requiring a global hard reset
        trit_in = 2'b10; #10; // TRIT_Z received -> Expected: frame_error = 0
        
        // Verification control frame to confirm safe post-error restoration (Value 2: 1 -> Z)
        trit_in = 2'b01; #10; // TRIT_1
        trit_in = 2'b10; #10; // TRIT_Z -> Expected: data_out = 2, data_ready = 1
        #20;

        $display("[+] All RTL pipeline tests executed. Check dump.vcd for wave verification.");
        $finish; // Terminate design simulation loop
    end
endmodule
