#!/bin/bash

trap "exit" INT TERM
trap "kill 0" EXIT


SCRIPTDIR=$(dirname "$0")
GCC_TOOLCHAIN=${PULP_RISCV_GCC_TOOLCHAIN_CI:-${PULP_RISCV_GCC_TOOLCHAIN:-}}

if [ -z "$GCC_TOOLCHAIN" ]; then
  echo "Set PULP_RISCV_GCC_TOOLCHAIN to the PULP toolchain directory." >&2
  exit 1
fi

# Override OPENOCD_CONFIG to use another adapter such as the Digilent HS2.
"$OPENOCD/bin/openocd" -f "${OPENOCD_CONFIG:-$SCRIPTDIR/openocd-arty-olimex.cfg}" &
sleep 3

# Open UART before GDB starts the application so short-lived output is captured.
(sleep 1; "$GCC_TOOLCHAIN/bin/riscv32-unknown-elf-gdb" -x "$SCRIPTDIR/elf_run.gdb" "$1") &
python3 -m serial.tools.miniterm "${UART_PORT:-/dev/ttyUSB0}" 115200 --raw --dtr 0 --rts 0
