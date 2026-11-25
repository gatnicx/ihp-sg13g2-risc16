// -----------------------------------------------------------------------------
// risc16_core.v
// Educational 16-bit multi-cycle RISC processor core.
//
// Architecture:
//   - 16-bit datapath and 16-bit instruction words
//   - 8 general-purpose registers; R0 is hardwired to zero
//   - 8-bit word-addressed PC (256 instruction words)
//   - Separate instruction and data memory interfaces (Harvard style)
//   - Multi-cycle FSM: FETCH -> DECODE -> EXECUTE -> MEMORY/WRITEBACK
//   - External memories are intentionally not instantiated in this core.
//
// Reset:
//   - Active-low, synchronous reset (sampled on rising edge of clk)
//
// Memory interface assumptions:
//   - Instruction memory is combinational/asynchronous read.
//   - Data memory is combinational/asynchronous read; writes occur on the
//     rising edge while dmem_we is asserted.
//   - Data addresses are 8-bit WORD addresses (256 x 16-bit address space).
//
// See ../ISA.md for the instruction encoding.
// -----------------------------------------------------------------------------

module risc16_core (
    input  wire        clk,
    input  wire        rst_n,

    // Instruction memory interface
    output wire [7:0]  imem_addr,
    input  wire [15:0] imem_rdata,

    // Data memory interface
    output reg  [7:0]  dmem_addr,
    output reg  [15:0] dmem_wdata,
    output wire        dmem_re,
    output wire        dmem_we,
    input  wire [15:0] dmem_rdata,

    // Status output
    output wire        halted
);

    // FSM states
    localparam [2:0] ST_FETCH   = 3'd0;
    localparam [2:0] ST_DECODE  = 3'd1;
    localparam [2:0] ST_EXECUTE = 3'd2;
    localparam [2:0] ST_MEMORY  = 3'd3;
    localparam [2:0] ST_WB      = 3'd4;
    localparam [2:0] ST_HALT    = 3'd5;

    // Opcode values
    localparam [3:0] OP_RTYPE = 4'h0;
    localparam [3:0] OP_ADDI  = 4'h1;
    localparam [3:0] OP_ANDI  = 4'h2;
    localparam [3:0] OP_ORI   = 4'h3;
    localparam [3:0] OP_XORI  = 4'h4;
    localparam [3:0] OP_LD    = 4'h5;
    localparam [3:0] OP_ST    = 4'h6;
    localparam [3:0] OP_BEQ   = 4'h7;
    localparam [3:0] OP_BNE   = 4'h8;
    localparam [3:0] OP_JAL   = 4'h9;
    localparam [3:0] OP_LUI   = 4'hA;
    localparam [3:0] OP_SLTI  = 4'hB;
    localparam [3:0] OP_HALT  = 4'hF;

    // R-type function values
    localparam [2:0] FN_ADD = 3'b000;
    localparam [2:0] FN_SUB = 3'b001;
    localparam [2:0] FN_AND = 3'b010;
    localparam [2:0] FN_OR  = 3'b011;
    localparam [2:0] FN_XOR = 3'b100;
    localparam [2:0] FN_SLT = 3'b101;
    localparam [2:0] FN_SLL = 3'b110;
    localparam [2:0] FN_SRL = 3'b111;

    reg [2:0]  state;
    reg [7:0]  pc;
    reg [15:0] ir;

    // 8 x 16-bit register file. Register zero is architecturally constant zero.
    reg [15:0] reg_file [0:7];

    reg [15:0] alu_result;
    reg [15:0] mem_read_data;
    reg [2:0]  destination_reg;
    reg        writeback_from_memory;
    reg        mem_is_store;

    integer reset_index;

    // Instruction fields for R-type and I-type instructions.
    wire [3:0] opcode;
    wire [2:0] rd;
    wire [2:0] rs1;
    wire [2:0] rs2;
    wire [2:0] funct;

    assign opcode = ir[15:12];
    assign rd     = ir[11:9];
    assign rs1    = ir[8:6];
    assign rs2    = ir[5:3];
    assign funct  = ir[2:0];

    // Register-file read values. R0 always reads as zero.
    wire [15:0] rs1_value;
    wire [15:0] rs2_value;
    wire [15:0] branch_rs1_value;
    wire [15:0] branch_rs2_value;
    wire [2:0]  branch_rs1;
    wire [2:0]  branch_rs2;
    wire [15:0] store_value;

    assign rs1_value = (rs1 == 3'd0) ? 16'd0 : reg_file[rs1];
    assign rs2_value = (rs2 == 3'd0) ? 16'd0 : reg_file[rs2];

    // BEQ/BNE encoding uses [11:9] as the first source and [8:6] as the second.
    assign branch_rs1 = ir[11:9];
    assign branch_rs2 = ir[8:6];
    assign branch_rs1_value = (branch_rs1 == 3'd0) ? 16'd0 : reg_file[branch_rs1];
    assign branch_rs2_value = (branch_rs2 == 3'd0) ? 16'd0 : reg_file[branch_rs2];

    // ST encoding uses [11:9] as the register whose value is written to memory.
    assign store_value = (rd == 3'd0) ? 16'd0 : reg_file[rd];

    wire [15:0] sign_imm6;
    wire [15:0] zero_imm6;
    wire [7:0]  sign_imm6_pc;

    assign sign_imm6     = {{10{ir[5]}}, ir[5:0]};
    assign zero_imm6     = {10'd0, ir[5:0]};
    assign sign_imm6_pc  = {{2{ir[5]}}, ir[5:0]};

    // Memory and status outputs.
    assign imem_addr = pc;
    assign dmem_re   = (state == ST_MEMORY) && !mem_is_store;
    assign dmem_we   = (state == ST_MEMORY) &&  mem_is_store;
    assign halted    = (state == ST_HALT);

    // Main sequential controller/datapath.
    always @(posedge clk) begin
        if (!rst_n) begin
            state                  <= ST_FETCH;
            pc                     <= 8'd0;
            ir                     <= 16'd0;
            alu_result             <= 16'd0;
            mem_read_data          <= 16'd0;
            destination_reg        <= 3'd0;
            writeback_from_memory  <= 1'b0;
            mem_is_store           <= 1'b0;
            dmem_addr              <= 8'd0;
            dmem_wdata             <= 16'd0;

            for (reset_index = 0; reset_index < 8; reset_index = reset_index + 1)
                reg_file[reset_index] <= 16'd0;
        end else begin
            // Enforce the architectural constant-zero register.
            reg_file[0] <= 16'd0;

            case (state)
                ST_FETCH: begin
                    ir    <= imem_rdata;
                    pc    <= pc + 8'd1;
                    state <= ST_DECODE;
                end

                ST_DECODE: begin
                    if (opcode == OP_HALT)
                        state <= ST_HALT;
                    else
                        state <= ST_EXECUTE;
                end

                ST_EXECUTE: begin
                    case (opcode)
                        OP_RTYPE: begin
                            destination_reg       <= rd;
                            writeback_from_memory <= 1'b0;

                            case (funct)
                                FN_ADD: alu_result <= rs1_value + rs2_value;
                                FN_SUB: alu_result <= rs1_value - rs2_value;
                                FN_AND: alu_result <= rs1_value & rs2_value;
                                FN_OR:  alu_result <= rs1_value | rs2_value;
                                FN_XOR: alu_result <= rs1_value ^ rs2_value;
                                FN_SLT: alu_result <= ($signed(rs1_value) < $signed(rs2_value)) ? 16'd1 : 16'd0;
                                FN_SLL: alu_result <= rs1_value << rs2_value[2:0];
                                FN_SRL: alu_result <= rs1_value >> rs2_value[2:0];
                                default: alu_result <= 16'd0;
                            endcase

                            state <= ST_WB;
                        end

                        OP_ADDI: begin
                            alu_result             <= rs1_value + sign_imm6;
                            destination_reg        <= rd;
                            writeback_from_memory  <= 1'b0;
                            state                  <= ST_WB;
                        end

                        OP_ANDI: begin
                            alu_result             <= rs1_value & zero_imm6;
                            destination_reg        <= rd;
                            writeback_from_memory  <= 1'b0;
                            state                  <= ST_WB;
                        end

                        OP_ORI: begin
                            alu_result             <= rs1_value | zero_imm6;
                            destination_reg        <= rd;
                            writeback_from_memory  <= 1'b0;
                            state                  <= ST_WB;
                        end

                        OP_XORI: begin
                            alu_result             <= rs1_value ^ zero_imm6;
                            destination_reg        <= rd;
                            writeback_from_memory  <= 1'b0;
                            state                  <= ST_WB;
                        end

                        OP_LD: begin
                            dmem_addr              <= rs1_value[7:0] + sign_imm6[7:0];
                            destination_reg        <= rd;
                            writeback_from_memory  <= 1'b1;
                            mem_is_store           <= 1'b0;
                            state                  <= ST_MEMORY;
                        end

                        OP_ST: begin
                            dmem_addr              <= rs1_value[7:0] + sign_imm6[7:0];
                            dmem_wdata             <= store_value;
                            writeback_from_memory  <= 1'b0;
                            mem_is_store           <= 1'b1;
                            state                  <= ST_MEMORY;
                        end

                        OP_BEQ: begin
                            if (branch_rs1_value == branch_rs2_value)
                                pc <= pc + sign_imm6_pc;
                            state <= ST_FETCH;
                        end

                        OP_BNE: begin
                            if (branch_rs1_value != branch_rs2_value)
                                pc <= pc + sign_imm6_pc;
                            state <= ST_FETCH;
                        end

                        OP_JAL: begin
                            // JAL writes the sequential return address into R7.
                            alu_result             <= {8'd0, pc};
                            destination_reg        <= 3'd7;
                            writeback_from_memory  <= 1'b0;
                            pc                     <= pc + ir[7:0];
                            state                  <= ST_WB;
                        end

                        OP_LUI: begin
                            alu_result             <= {ir[8:0], 7'b0};
                            destination_reg        <= rd;
                            writeback_from_memory  <= 1'b0;
                            state                  <= ST_WB;
                        end

                        OP_SLTI: begin
                            alu_result             <= ($signed(rs1_value) < $signed(sign_imm6)) ? 16'd1 : 16'd0;
                            destination_reg        <= rd;
                            writeback_from_memory  <= 1'b0;
                            state                  <= ST_WB;
                        end

                        default: begin
                            // Reserved opcodes behave as NOPs in this first version.
                            state <= ST_FETCH;
                        end
                    endcase
                end

                ST_MEMORY: begin
                    if (mem_is_store) begin
                        // External memory samples dmem_we and dmem_wdata on this edge.
                        state <= ST_FETCH;
                    end else begin
                        mem_read_data <= dmem_rdata;
                        state         <= ST_WB;
                    end
                end

                ST_WB: begin
                    if (destination_reg != 3'd0) begin
                        if (writeback_from_memory)
                            reg_file[destination_reg] <= mem_read_data;
                        else
                            reg_file[destination_reg] <= alu_result;
                    end
                    state <= ST_FETCH;
                end

                ST_HALT: begin
                    state <= ST_HALT;
                end

                default: begin
                    state <= ST_FETCH;
                end
            endcase
        end
    end

endmodule
