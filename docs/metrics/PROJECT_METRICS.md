# RISC16 — IHP SG13G2 Implementation Metrics

Run: RUN_2026-11-20_21-12-44
Flow status: 80/80 steps completed

## Physical Design

| Metric | Result |
|---|---:|
| Standard cells | 2,742 |
| Total instances | 7,942 |
| Standard-cell area | 37,233.3 µm² |
| Core area | 84,803.2 µm² |
| Die area | 97,540.5 µm² |
| Utilization | 43.9055% |
| Die width | 303.095 µm |
| Die height | 321.815 µm |
| Clock period | 20 ns |
| Target frequency | 50 MHz |
| Routed wirelength | 100,261 µm |
| Routed vias | 16,659 |

Total instances include physical-only cells such as fill cells.

## Post-route Timing

| PVT Corner | Voltage | Temperature | Setup Slack | Hold Slack |
|---|---:|---:|---:|---:|
| Fast | 1.32 V | -40°C | +13.2436 ns | +0.1116 ns |
| Typical | 1.20 V | 25°C | +11.8888 ns | +0.2964 ns |
| Slow | 1.08 V | 125°C | +9.4509 ns | +0.6432 ns |

Setup violations: 0
Hold violations: 0
Setup TNS: 0 ns
Hold TNS: 0 ns
Maximum slew violations: 0
Maximum capacitance violations: 0

## Power Estimate

Nominal corner: 1.20 V, 25°C.

| Component | Power |
|---|---:|
| Internal | 0.837211 mW |
| Switching | 0.266548 mW |
| Leakage | 0.003162 mW |
| Total | 1.106921 mW |

These are EDA estimates, not measured silicon power.

## Physical Verification

| Check | Result |
|---|---|
| Routing DRC | 0 errors |
| Magic DRC | 0 errors |
| KLayout DRC | 0 errors |
| LVS | 0 reported differences |
| Antenna | 0 reported violations |
| Power-grid checks | 0 reported violations |

## Known Issue

The final checks report 19 maximum-fanout violations associated
with CTS leaf clock-buffer outputs.

These are retained as a known clock-tree optimization item.
Setup and hold timing violation counts remain zero.

## RTL Functional Simulation

Simulation result: PASS
Execution length: 43 cycles

MEM[0] = 8
MEM[1] = 7
MEM[2] = 9
HALTED = 1

The 43-cycle result is from RTL functional simulation, not
post-layout SDF simulation.
