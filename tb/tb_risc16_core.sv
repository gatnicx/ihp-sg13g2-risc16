`timescale 1ns/1ps

module tb_risc16_core;

initial begin
    $dumpfile("risc16.vcd");
    $dumpvars(0, tb_risc16_core);
end

    reg         clk;
    reg         rst_n;
    wire [7:0]  imem_addr;
    wire [15:0] imem_rdata;
    wire [7:0]  dmem_addr;
    wire [15:0] dmem_wdata;
    wire        dmem_re;
    wire        dmem_we;
    wire [15:0] dmem_rdata;
    wire        halted;

    reg [15:0] instruction_memory [0:255];
    reg [15:0] data_memory        [0:255];

    integer i;
    integer cycles;

    risc16_core dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .dmem_addr  (dmem_addr),
        .dmem_wdata (dmem_wdata),
        .dmem_re    (dmem_re),
        .dmem_we    (dmem_we),
        .dmem_rdata (dmem_rdata),
        .halted     (halted)
    );

    // Clock: 10 ns period.
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Asynchronous-read memory models.
    assign imem_rdata = instruction_memory[imem_addr];
    assign dmem_rdata = data_memory[dmem_addr];

    // Synchronous data-memory write.
    always @(posedge clk) begin
        if (rst_n && dmem_we)
            data_memory[dmem_addr] <= dmem_wdata;
    end

    // Program:
    //  0: ADDI R1, R0, 5       ; R1 = 5
    //  1: ADDI R2, R0, 3       ; R2 = 3
    //  2: ADD  R3, R1, R2      ; R3 = 8
    //  3: ST   R3, 0(R0)       ; MEM[0] = 8
    //  4: LD   R4, 0(R0)       ; R4 = MEM[0] = 8
    //  5: BEQ  R3, R4, +2      ; branch to instruction 8
    //  6: HALT                 ; must be skipped by taken branch
    //  7: HALT                 ; must also be skipped by branch target
    //  8: JAL  +2              ; R7 = 9, jump to instruction 11
    //  9: ADDI R6, R0, 20      ; must be skipped by JAL
    // 10: HALT                 ; must be skipped by JAL
    // 11: ADDI R6, R0, 7       ; R6 = 7
    // 12: ST   R6, 1(R0)       ; MEM[1] = 7
    // 13: ST   R7, 2(R0)       ; MEM[2] = return address 9
    // 14: HALT
    initial begin
        rst_n = 1'b0;
        cycles = 0;

        for (i = 0; i < 256; i = i + 1) begin
            instruction_memory[i] = 16'h0000; // NOP: ADD R0, R0, R0
            data_memory[i]        = 16'h0000;
        end

        instruction_memory[0]  = 16'h1205;
        instruction_memory[1]  = 16'h1403;
        instruction_memory[2]  = 16'h0650;
        instruction_memory[3]  = 16'h6600;
        instruction_memory[4]  = 16'h5800;
        instruction_memory[5]  = 16'h7702;
        instruction_memory[6]  = 16'hF000;
        instruction_memory[7]  = 16'hF000;
        instruction_memory[8]  = 16'h9002;
        instruction_memory[9]  = 16'h1C14;
        instruction_memory[10] = 16'hF000;
        instruction_memory[11] = 16'h1C07;
        instruction_memory[12] = 16'h6C01;
        instruction_memory[13] = 16'h6E02;
        instruction_memory[14] = 16'hF000;

        // Release synchronous reset away from the active clock edge.
        repeat (3) @(negedge clk);
        rst_n = 1'b1;

        // Wait for HALT, with a finite timeout to catch a stuck core.
        while ((halted !== 1'b1) && (cycles < 200)) begin
            @(posedge clk);
            cycles = cycles + 1;
        end
        #1;

        if (halted !== 1'b1)
            $fatal(1, "FAIL: processor did not reach HALT within 200 cycles");

        if (data_memory[0] !== 16'd8)
            $fatal(1, "FAIL: MEM[0] expected 8, got %0d", data_memory[0]);

        if (data_memory[1] !== 16'd7)
            $fatal(1, "FAIL: MEM[1] expected 7, got %0d", data_memory[1]);

        if (data_memory[2] !== 16'd9)
            $fatal(1, "FAIL: MEM[2] expected JAL return address 9, got %0d", data_memory[2]);

        $display("PASS: RISC16 test completed in %0d cycles", cycles);
        $display("      MEM[0] = %0d (ADD + STORE + LOAD + BEQ)", data_memory[0]);
        $display("      MEM[1] = %0d (JAL target path + ADDI + STORE)", data_memory[1]);
        $display("      MEM[2] = %0d (JAL link register R7)", data_memory[2]);
        $display("      HALTED = %0b", halted);
        $finish;
    end

endmodule
