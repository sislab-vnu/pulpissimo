#!/usr/bin/env bash

if [[ -z "${PULP_RISCV_GCC_TOOLCHAIN:-}" ]]; then
  printf 'Set PULP_RISCV_GCC_TOOLCHAIN before sourcing platformio/env.sh\n' >&2
  return 1 2>/dev/null || exit 1
fi

_platformio_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
export PULPISSIMO_ROOT="$(dirname -- "$_platformio_dir")"
export OPENOCD="$PULPISSIMO_ROOT/build/tools/openocd"
export PLATFORMIO_PLATFORMS_DIR="$PULPISSIMO_ROOT/.pio-platforms"
export PATH="$PULP_RISCV_GCC_TOOLCHAIN/bin:$PATH"
unset _platformio_dir
