#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkdir -p build/obj_dir

echo "== Verilator lint =="
verilator --lint-only --Wall --Wno-fatal --top-module risc16_core src/risc16_core.v

echo
echo "== Build self-checking simulation =="
verilator --binary --timing --trace-vcd --Wall --Wno-fatal \
  --top-module tb_risc16_core \
  --Mdir build/obj_dir \
  src/risc16_core.v tb/tb_risc16_core.sv

echo
echo "== Run simulation =="
./build/obj_dir/Vtb_risc16_core
