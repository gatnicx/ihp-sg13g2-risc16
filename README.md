# RISC16 Processor Core — IHP SG13G2

A custom 16-bit multi-cycle RISC processor designed in Verilog and taken
through an RTL-to-GDSII ASIC physical-design flow using the IHP SG13G2
technology and open-source EDA tools.

## Project Overview

This project covers the implementation and verification of a custom
16-bit RISC processor, followed by synthesis, physical implementation,
timing analysis and final GDSII generation.

### Architecture

- Custom 16-bit instruction set (not RISC-V)
- 16-bit datapath
- 8 general-purpose registers, each 16 bits wide
- R0 hardwired to zero
- R7 used as the JAL link register
- 8-bit word-addressed program counter
- Separate instruction and data memory interfaces
- Multi-cycle finite-state-machine controller
- Active-low synchronous reset

![RISC16 architecture](docs/architecture/architecture_overview.jpg)

See [ISA.md](ISA.md) for instruction encodings and architectural details.

## Instruction Set

The ISA definition includes:

| Category | Instructions |
|---|---|
| Arithmetic | ADD, SUB, ADDI |
| Logical | AND, OR, XOR, ANDI, ORI, XORI |
| Comparison | SLT, SLTI |
| Shift | SLL, SRL |
| Memory | LD, ST |
| Branch | BEQ, BNE |
| Jump | JAL |
| Upper immediate | LUI |
| Control | HALT |

The testbench exercises arithmetic, load/store, branch, jump/link
and halt paths. The complete ISA definition is documented in ISA.md.

## RTL Functional Verification

Simulation was performed using Verilator 5.044 with a self-checking
SystemVerilog testbench.

### Verified simulation result

```text
PASS: RISC16 test completed in 43 cycles
MEM[0] = 8
MEM[1] = 7
MEM[2] = 9
HALTED = 1

