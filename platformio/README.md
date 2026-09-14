# PlatformIO Support

This directory is a repository-local PlatformIO development platform for
PULPissimo on the Digilent Arty A7-100T. It builds applications with the
checked-out `sw/pulp-runtime`; it does not download the outdated runtime and
tool packages from `platformio/platform-openhw`.

## Prerequisites

Install PlatformIO Core or the PlatformIO IDE extension. In Bash, set the PULP
RISC-V toolchain location, optionally set `XC3SPROG` for FPGA programming, and
source the environment helper from the repository root:

```shell
export PULP_RISCV_GCC_TOOLCHAIN=/path/to/pulp-riscv-toolchain
export XC3SPROG=/path/to/xc3sprog
source platformio/env.sh
```

The helper sets `PULPISSIMO_ROOT`, defaults `OPENOCD` to
`build/tools/openocd`, adds the selected compiler to `PATH`, and keeps local
platform links under `.pio-platforms`. The checkout-specific platform directory
prevents multiple PULPissimo worktrees from sharing stale links. Override
`OPENOCD` after sourcing the helper when using another compatible installation.

Launch VS Code from this shell when using PlatformIO IDE so it inherits the
same environment.

## Examples

| Project | Demonstrates | Hardware observation |
| --- | --- | --- |
| `hello` | Minimal runtime and UART output | Prints `Hello !` and exits |
| `gpio-blink` | Pad mux and GPIO output | Blinks LED0 five times and exits |
| `gpio-switch` | GPIO input and output | Continuously mirrors SW0 to LED0 |
| `uart-echo` | Blocking UART transfers | Echoes characters until `q` |
| `uart-buffered` | 32-byte UART uDMA transfers | Echoes one exact-size block |
| `performance` | Cycle and instruction counters | Runs a convolution benchmark |
| `performance-events` | Configurable HPM events | Sweeps five event types |
| `timer-interrupt` | Periodic FC timer interrupts | Handles five 100 ms periods |
| `memory-benchmark` | Sequential L2 throughput | Measures reads, writes, and copies |

## Hello Example

Open `platformio/examples/hello` as the PlatformIO project, or use the CLI:

```shell
cd platformio/examples/hello
pio run
```

The environment uses the current checkout directly through
`platform = symlink://${sysenv.PULPISSIMO_ROOT}/platformio` and uses the same
absolute root for the runtime, bitstream, and OpenOCD configuration. It builds
for the FPGA's CV32E40P ZFINX configuration. Projects elsewhere can use the
same settings after sourcing this checkout's `platformio/env.sh`.

Program the FPGA through the onboard Digilent JTAG interface:

```shell
pio run --target upload_bitstream
```

Open the Digilent UART before loading the short-lived hello application:

```shell
pio device monitor --port "$UART_PORT" --baud 115200
```

In another terminal, load and run the ELF through the Olimex adapter on PMOD
JA:

```shell
pio run --target upload
```

The serial monitor should print:

```text
Hello !
```

## GPIO Blink Example

`platformio/examples/gpio-blink` configures pad 8 with the runtime pad-mux and
GPIO APIs, then blinks the Arty LED0 five times. Build the project, open the
UART monitor, and upload it using the same commands as the hello example. UART
output confirms when the sequence starts and completes.

## GPIO Switch Example

`platformio/examples/gpio-switch` configures Arty SW0 as GPIO input and mirrors
its state continuously to LED0. The UART reports each switch transition. Reset
the board or upload another application to stop it.

## UART Echo Example

`platformio/examples/uart-echo` demonstrates blocking UART input and output.
Build it, open the serial monitor, and upload the application. Typed characters
are sent back through the Digilent USB-UART bridge; enter `q` to exit.

## Buffered UART Example

`platformio/examples/uart-buffered` receives and retransmits one 32-byte block
with the UART's uDMA channels. Send
`0123456789abcdef0123456789abcdef` to provide an exact-size test block.

## Performance Example

`platformio/examples/performance` runs a deterministic 5x5 integer convolution
and reports hardware performance-counter deltas for cycles, retired
instructions, and retired loads. It also derives CPI, cycles per output, and
multiply-accumulates per cycle before checking the result.

Build it with:

```shell
cd platformio/examples/performance
pio run
```

Open the UART monitor, then upload the benchmark through the Olimex adapter as
shown for the hello example. The default workload performs 1000 iterations.
Override it in `platformio.ini` when a shorter or longer sample is useful:

```ini
build_flags = -DBENCHMARK_ITERATIONS=2000
```

The CV32E40P configuration has fixed cycle and retired-instruction counters and
one configurable event counter. This example assigns that event counter to
retired loads. It takes start/end deltas instead of calling `perf_reset()` so
preexisting counter values do not affect the measurement. The runtime reads
the low 32 bits of each counter, so keep one measured interval below
2^32 core cycles (about 429 seconds at 10 MHz).

## Performance Event Sweep

`platformio/examples/performance-events` reruns one deterministic workload for
each configurable counter event. It reports retired loads, retired stores,
branches, taken branches, and compressed instructions while checking that each
run produces the same checksum.

## Timer Interrupt Example

`platformio/examples/timer-interrupt` configures the FC timer for a periodic
100 ms interrupt, waits with `wfi`, and verifies that five interrupts arrive.

## Memory Benchmark

`platformio/examples/memory-benchmark` measures repeated 16 KiB sequential L2
reads, writes, and copies. It reports logical transfer bandwidth at the active
core clock and validates the resulting data and checksum.

Start a debug session from PlatformIO IDE's Debug toolbar. The equivalent
interactive CLI command is:

```shell
pio debug --interface gdb -- -x .pioinit
```

The `upload_bitstream` target uses `XC3SPROG` when set, while upload and debug
use `OPENOCD`. Set `custom_bitstream`, `custom_toolchain`, `custom_openocd`, or
`custom_xc3sprog` in `platformio.ini` to override those paths for one project.

## Automation

Build all repository examples from the PULPissimo root with:

```shell
make platformio-examples
```

Override `PIO` when PlatformIO Core is not on `PATH`. For example:

```shell
make platformio-examples PIO="$HOME/.platformio/penv/bin/pio"
```

With the FPGA already programmed and both JTAG adapters connected, run all
finite UART-observable hardware tests with:

```shell
make platformio-smoke UART_PORT=/dev/ttyUSB2
```

Close PlatformIO Monitor, miniterm, and any other process using the UART before
starting the suite. The Linux smoke runner uses only Python's standard library
and takes exclusive ownership of the serial device while running. It skips the
continuous `gpio-switch` example. Pass additional options through
`PLATFORMIO_SMOKE_ARGS`; for example, program the FPGA first or select one test:

```shell
make platformio-smoke UART_PORT=/dev/ttyUSB2 \
  PLATFORMIO_SMOKE_ARGS="--upload-bitstream --example timer-interrupt"
```

## Generated Files

PlatformIO stores build products under each example's `.pio` directory and the
checkout-local platform link under `.pio-platforms`. Both are ignored by Git.
Use `pio run --target clean` to remove an example's build products. Generate
IDE compile metadata with:

```shell
pio run --target compiledb
```
