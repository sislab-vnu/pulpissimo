# Arty A7 FPGA and Default RTL Simulation

The Arty A7 implementation and the default QuestaSim environment use the same
PULPissimo SoC RTL, but they are different platforms around that RTL. This
document describes the differences that matter when moving software or debug
flows between them.

## At a Glance

| Area | Arty A7 FPGA | Default RTL simulation |
|------|--------------|------------------------|
| Tool | Xilinx Vivado | Siemens QuestaSim |
| Bender targets | `fpga`, `xilinx` | `rtl`, `test`, `rtl_sim` |
| Top level | `xilinx_pulpissimo` | `tb_pulp` (optimized as `vopt_tb`) |
| Clock source | Physical 100 MHz board oscillator and Xilinx clock IP | Behavioral 32.769 kHz reference clock and FLL models |
| Default SoC/peripheral clocks | Fixed at 10 MHz/5 MHz | Configured by software through the modeled FLL interface |
| External environment | Physical board pins and peripherals | SystemVerilog testbench and optional verification IP |
| Program loading | Physical PULPissimo JTAG connection | Testbench-assisted SREC/JTAG loading or remote OpenOCD |
| Main output | Routed `.bit` and `.bin` images plus timing reports | Compiled and optimized simulation libraries, waves, and logs |
| Timing | Subject to FPGA placement, routing, and XDC constraints | Functional RTL timing; no FPGA timing closure |

## Shared SoC RTL

Both platforms instantiate `hw/pulpissimo.sv` and `hw/soc_domain.sv`. The CPU,
interconnect, memories, uDMA, and peripheral register interfaces therefore come
from the same SoC design and Bender dependency lock.

Platform-specific files are selected around the shared design:

- The Arty build selects `hw/fpga_autogen_rom.sv`, `hw/clock_gen_fpga.sv`, the
  Xilinx wrapper, clocking IP, and board constraints.
- The default simulation selects `hw/asic_autogen_rom.sv`,
  `hw/clock_gen_generic.sv`, and the simulation testbench sources.
- Dependencies may also select FPGA-synthesizable or simulation-specific
  implementations according to the active Bender targets.

This means a successful RTL simulation validates the configured RTL behavior,
but does not validate the FPGA wrapper, pin mapping, Xilinx IP, or routed timing.

## Top Level and Core Configuration

The Arty top level is
`target/fpga/pulpissimo-arty/rtl/xilinx_pulpissimo.v`. It exposes only signals
that are mapped to board resources, instantiates the 100 MHz input clock buffer,
and instantiates PULPissimo with these settings:

- CV32E40P core (`CORE_TYPE=0`)
- FPU enabled
- HWPE disabled
- Zfinx inherited from the `pulpissimo` default, currently enabled
- Simulated standard output disabled

The default QuestaSim top level is `target/sim/tb/tb_pulp.sv`. Its default
PULPissimo configuration also uses CV32E40P with the FPU enabled and HWPE
disabled, but explicitly disables Zfinx and enables simulated standard output.
Software must be built for the core and floating-point register-file
configuration of the platform on which it will run.

## Clocks

### Arty A7

The board supplies a physical 100 MHz clock. Two Xilinx Clocking Wizard
instances and a divider generate the platform clocks:

| Clock | Default |
|-------|---------|
| SoC/core | 10 MHz |
| Peripheral | 5 MHz |
| Slow clock | Approximately 32.769 kHz |

The clock values are set by `FC_CLK_PERIOD_NS`, `PER_CLK_PERIOD_NS`, and
`SLOW_CLK_PERIOD_NS` in `fpga-settings.mk` when the clock IP is generated. The
FPGA clock generator does not implement runtime FLL reconfiguration: accesses
to its APB configuration interface return an error response. Firmware for this
target must use the fixed FPGA frequencies.

### Default Simulation

The testbench drives a behavioral reference clock with a default period of
30,517 ns. `clock_gen_generic.sv` contains behavioral FLL models for the SoC and
peripheral clocks and exposes their configuration interface to software. The
slow clock is derived directly from the reference clock unless bypassed.

The simulated clock frequencies can consequently reflect runtime FLL
configuration. They should not be assumed to match the Arty defaults unless the
software configuration does so deliberately.

## Reset, Boot Selection, and JTAG

On Arty, reset and JTAG are physical signals. The reset button drives the
active-low reset input. PULPissimo JTAG is routed to PMOD A and requires an
external JTAG adapter; the board's FPGA configuration JTAG connection is not
connected to the PULPissimo JTAG port.

The Vivado flow removes unused boot-selection and JTAG-reset pad cells after
synthesis. Both boot-selection inputs are tied low and the internal JTAG reset
is tied high. HyperBus pads are also removed and their inputs are tied low.
These are fixed implementation choices rather than testbench controls.

In the default simulation, `tb_pulp` generates reset and JTAG activity. The
normal `run_sim` flow converts an ELF file to SREC and passes it to the
testbench, which loads it through the PULP TAP by default. Testbench plusargs
can select the RISC-V debug-module TAP or make the simulation wait for an
OpenOCD remote-bitbang connection. These testbench loading mechanisms are
simulation infrastructure and do not represent a physical memory-loading path.

## Pads and Peripherals

The Arty wrapper maps the 32 muxed PULPissimo I/O pads to physical UART, SPI,
SDIO, I2C, PMOD, LED, switch, and button pins. The mappings are defined by
`xilinx_pulpissimo.v` and `constraints/arty-a7.xdc`; the board README lists the
user-visible assignments. Any unconnected or repurposed SoC pads must be
treated according to this physical mapping.

The default testbench aliases the muxed pads to behavioral peripheral signals.
It can use optional flash, I2C, I2S, and camera verification IP when enabled.
These models provide stimulus and checking, but do not model all board-level
electrical effects, connector assignments, or external-device timing.

The Arty configuration QSPI flash is not currently usable as a PULPissimo user
flash. Its clock is on a dedicated FPGA configuration pin and the required
`STARTUPE2` connection is disabled in the wrapper. A flash boot that works with
the simulation model therefore does not establish that the same path works on
this board implementation.

## Constraints and Results

Vivado applies two Arty constraint sets:

- `constraints/arty-a7.xdc` defines package pins, I/O standards, and the primary
  board clock.
- `constraints/arty-a7-impl.xdc` is applied late during implementation for
  generated-clock and clock-domain timing relationships.

The FPGA flow synthesizes, places, routes, writes the bitstream, and produces
timing reports. A generated bitstream is not sufficient by itself: inspect the
reports for timing and implementation errors before testing hardware.

QuestaSim compiles the selected RTL and optimizes `tb_pulp` into `vopt_tb`.
Simulation provides waves, protocol models, and testbench diagnostics, but it
does not run FPGA placement/routing or apply the board XDC constraints.

## Build and Run

Run commands from the repository root unless noted otherwise.

Build the default QuestaSim platform:

```sh
make checkout
make build
```

Run an ELF directly:

```sh
make run_sim EXECUTABLE_PATH=/absolute/path/to/application.elf
```

Build an Arty bitstream:

```sh
make arty rev=artyA7-35T
# or
make arty rev=artyA7-100T
```

The top-level FPGA Makefile copies the results to
`target/fpga/pulpissimo_arty.bit` and `target/fpga/pulpissimo_arty.bin`.
Program a connected Arty A7-100T from `target/fpga` with:

```sh
make -C pulpissimo-arty download rev=artyA7-100T
```

The revision names select different Vivado parts and board definitions. Note
that the current `artyA7-35T` setting selects `xc7a50ticsg324-1L` while using
the Digilent Arty A7-35 board definition. Confirm that this is intentional for
the installed board and Vivado version before relying on that target.

## Interpreting Results

- Use RTL simulation for fast software iteration, waveform inspection,
  testbench-driven loading, and modeled peripheral verification.
- Use the FPGA implementation to validate synthesis, physical timing, board pin
  mappings, real JTAG/UART behavior, and interaction with attached hardware.
- Match firmware clock constants and ISA options to the selected platform.
- Do not treat simulation-only preload paths or peripheral models as evidence
  that the equivalent physical Arty connection is implemented.
- Do not treat FPGA timing closure as a replacement for functional regression
  testing in simulation.
