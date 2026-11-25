# RISC16 ISA — first implementation

## Architectural parameters

| Item | Definition |
|---|---|
| Instruction width | 16 bits |
| Data width | 16 bits |
| Register file | 8 × 16-bit registers |
| R0 | Hardwired to zero |
| PC | 8 bits, word-addressed |
| Instruction memory | 256 × 16-bit words, external |
| Data memory | 256 × 16-bit words, external |
| Memory organization | Harvard (separate instruction/data ports) |
| Execution | Multi-cycle FSM |
| Reset | Active-low synchronous |

The core exposes memory interfaces rather than instantiating large arrays internally. This keeps the CPU core suitable for ASIC synthesis and allows memories to be modeled in simulation or replaced with SRAM macros later.

## Instruction encoding

All instructions are one 16-bit word. Opcode is `instr[15:12]`.

### R-type: opcode `0x0`

| Bits | Field |
|---|---|
| [15:12] | `0000` |
| [11:9] | `rd` |
| [8:6] | `rs1` |
| [5:3] | `rs2` |
| [2:0] | `funct` |

| funct | Operation |
|---|---|
| 000 | `ADD rd, rs1, rs2` |
| 001 | `SUB rd, rs1, rs2` |
| 010 | `AND rd, rs1, rs2` |
| 011 | `OR rd, rs1, rs2` |
| 100 | `XOR rd, rs1, rs2` |
| 101 | `SLT rd, rs1, rs2` (signed comparison; result 0 or 1) |
| 110 | `SLL rd, rs1, rs2` (shift amount is `rs2[2:0]`) |
| 111 | `SRL rd, rs1, rs2` (logical right shift by `rs2[2:0]`) |

### I-type and memory instructions

For `ADDI`, `ANDI`, `ORI`, `XORI`, `LD`, `ST`, and `SLTI`:

| Bits | Field |
|---|---|
| [15:12] | opcode |
| [11:9] | destination (`rd`) or store source register |
| [8:6] | source/base register (`rs1`) |
| [5:0] | immediate / word offset |

| Opcode | Instruction | Meaning |
|---|---|---|
| 1 | `ADDI rd, rs1, imm6` | `rd = rs1 + sign_extend(imm6)` |
| 2 | `ANDI rd, rs1, imm6` | `rd = rs1 & zero_extend(imm6)` |
| 3 | `ORI rd, rs1, imm6` | `rd = rs1 | zero_extend(imm6)` |
| 4 | `XORI rd, rs1, imm6` | `rd = rs1 ^ zero_extend(imm6)` |
| 5 | `LD rd, offset(rs1)` | Load one 16-bit word from data memory |
| 6 | `ST rs2, offset(rs1)` | Store register selected by bits `[11:9]` |
| B | `SLTI rd, rs1, imm6` | Signed less-than; result 0 or 1 |

The six-bit load/store offset is signed and measured in **words**, not bytes. The effective address is truncated to eight bits.

### Branch instructions

`BEQ` and `BNE` use:

| Bits | Field |
|---|---|
| [15:12] | opcode (`7` for BEQ, `8` for BNE) |
| [11:9] | first compare register |
| [8:6] | second compare register |
| [5:0] | signed PC-relative word offset |

The PC is incremented during fetch. A taken branch sets `PC = current_sequential_PC + sign_extend(imm6)`.

### Jump and upper immediate

| Opcode | Instruction | Meaning |
|---|---|---|
| 9 | `JAL offset8` | `R7 = sequential_PC`; `PC = sequential_PC + sign_extend(offset8)` |
| A | `LUI rd, imm9` | `rd = {imm9, 7'b0}` |
| F | `HALT` | Stop execution and assert `halted` |

R0 reads as zero and ignores writes. Writes to R7 by normal instructions are allowed; JAL overwrites R7 with the return address.

## First test program

The supplied testbench verifies:

1. ADDI and ADD arithmetic.
2. Store to and load from external data memory.
3. BEQ taken branch behavior.
4. JAL PC-relative target and R7 link address.
5. HALT behavior.

This is an initial educational ISA, not an implementation of an existing commercial or standardized ISA such as RISC-V. The name RISC16 refers to this custom 16-bit RISC architecture.
