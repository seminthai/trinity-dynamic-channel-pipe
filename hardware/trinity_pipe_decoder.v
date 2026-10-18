`timescale 1ns/1ps

module trinity_pipe_decoder (
    input  wire        clk,         // Bus clock frequency
    input  wire        rst_n,       // Asynchronous hardware reset (active low)
    input  wire [1:0]  trit_in,     // Ternary token: 00=T0, 01=T1, 10=TZ, 11=IDLE
    
    output reg  [3:0]  data_out,    // Restored 4-bit nibble
    output reg         data_ready,  // Data ready strobe (active for 1 clk cycle)
    output reg         frame_error  // Hardware framing error flag (timeout)
);

    // Ternary alphabet encoding + Physical Idle State
    localparam TRIT_0   = 2'b00;
    localparam TRIT_1   = 2'b01;
    localparam TRIT_Z   = 2'b10;
    localparam BUS_IDLE = 2'b11; // Line is quiet / No transmission

    // Internal hardware register counters
    reg [2:0] bit_count;
    reg [3:0] pattern;

    // Combinatorial decoding logic matrix
    reg [3:0] decoded_value;
    reg       invalid_combination;

    always @(*) begin
        decoded_value       = 4'b0000;
        invalid_combination = 1'b0;
        
        case (bit_count)
            3'd0: decoded_value = 4'd0; // [Z] -> 0
            
            3'd1: begin // [0Z] -> 1, [1Z] -> 2
                if (pattern == 1'b1) decoded_value = 4'd2;
                else                 decoded_value = 4'd1;
            end
            
            3'd2: begin // [00Z] -> 3 ... [11Z] -> 6
                decoded_value = 4'd3 + pattern[1:0];
            end
            
            3'd3: begin // [000Z] -> 7 ... [111Z] -> 14
                decoded_value = 4'd7 + pattern[2:0];
            end
            
            3'd4: begin // [0000Z] -> 15
                if (pattern[3:0] == 4'b0000) decoded_value = 4'd15;
                else                         invalid_combination = 1'b1;
            end
            
            default: invalid_combination = 1'b1;
        endcase
    end

    // Sequential Finite State Machine (FSM) logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_count   <= 3'b000;
            pattern     <= 4'b0000;
            data_out    <= 4'b0000;
            data_ready  <= 1'b0;
            frame_error <= 1'b0;
        end else begin
            // Default strobe reset
            data_ready <= 1'b0;

            case (trit_in)
                TRIT_0, TRIT_1: begin
                    if (frame_error) begin
                        bit_count <= 3'b000;
                        pattern   <= 4'b0000;
                    end
                    else if (bit_count >= 3'd4) begin
                        frame_error <= 1'b1;
                        bit_count   <= 3'b000;
                        pattern     <= 4'b0000;
                    end else begin
                        pattern   <= (pattern << 1) | trit_in[0];
                        bit_count <= bit_count + 1'b1;
                    end
                end

                TRIT_Z: begin
                    // Every explicit TZ edge triggers immediate free-latch decoding
                    if (!invalid_combination && !frame_error) begin
                        data_out   <= decoded_value;
                        data_ready <= 1'b1;
                    end
                    
                    // Instant flush to prepare for the next transmission burst
                    bit_count   <= 3'b000;
                    pattern     <= 4'b0000;
                    frame_error <= 1'b0;
                end

                BUS_IDLE: begin
                    // In IDLE state, the decoder maintains its current internal registers
                    // and simply waits for new data bits (TRIT_0 or TRIT_1) or a fresh zero.
                    bit_count   <= bit_count;
                    pattern     <= pattern;
                end

                default: begin
                    frame_error <= 1'b1;
                    bit_count   <= 3'b000;
                    pattern     <= 4'b0000;
                end
            endcase
        end
    end

endmodule
