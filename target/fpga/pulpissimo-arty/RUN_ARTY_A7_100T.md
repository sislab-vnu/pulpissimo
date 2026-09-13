# Running PULPissimo on Arty A7-100T

This guide describes the verified sequence for programming the FPGA, loading
software through the PULPissimo JTAG port, and monitoring UART output. Run the
commands from the PULPissimo repository root unless stated otherwise.

## Hardware Connections

Two independent JTAG connections are used:

- Connect the Arty `PROG` USB port. Its onboard Digilent JTAG interface programs
  the FPGA configuration.
- Connect an Olimex ARM-USB-OCD-H to PMOD JA. This external adapter accesses the
  PULPissimo JTAG port after the FPGA has been programmed.

Connect the Olimex adapter to PMOD JA as follows:

| JTAG signal | PMOD pin |
|-------------|----------|
| TMS         | JA1      |
| TDI         | JA2      |
| TDO         | JA3      |
| TCK         | JA4      |
| GND         | JA5      |
| VCC target  | JA6      |

## Tools

The verified setup used:

- `xc3sprog` with the `nexys4` cable profile for the onboard Digilent JTAG.
- The PULP-compatible OpenOCD build. Upstream RISC-V OpenOCD cannot address
  PULPissimo's hart 992; see upstream issue 359.
- A PULP RISC-V GCC/GDB toolchain.
- Python 3 with PySerial.

For the local installation used during verification:

```shell
export XC3SPROG=/home/tools/riscv/programmer/xc3prog/bin/xc3sprog
export OPENOCD="$PWD/build/tools/openocd"
export PULP_RISCV_GCC_TOOLCHAIN=/home/tools/riscv/toolchains/pulp/v2.6.0
export PATH="$PULP_RISCV_GCC_TOOLCHAIN/bin:$PATH"
```

## 1. Build the Bitstream

Skip this step when `target/fpga/pulpissimo_arty.bit` already exists.

```shell
make arty rev=artyA7-100T
```

## 2. Program the FPGA

Close Vivado Hardware Manager and any process using the onboard JTAG adapter,
then program the volatile FPGA configuration:

```shell
"$XC3SPROG" -c nexys4 target/fpga/pulpissimo_arty.bit
```

A non-destructive chain scan should identify the Arty A7-100T FPGA as an
`XA7A100T` with IDCODE `0x13631093`:

```shell
"$XC3SPROG" -c nexys4
```

This step must complete before OpenOCD can see the PULPissimo JTAG chain through
the external Olimex adapter.

## 3. Build an FPGA Application

The hello regression test provides a small UART smoke test. Build it for the
FPGA platform so the runtime uses UART rather than simulation output:

```shell
export PULPRT_CONFIG_CFLAGS="-I$PWD/sw/pulp-runtime/drivers/pulpissimo/rtl_sim/io_mux/include"
source sw/pulp-runtime/configs/pulpissimo_cv32.sh
make -C sw/regression_tests/hello clean all platform=fpga
```

The resulting ELF is:

```text
sw/regression_tests/hello/build/test/test
```

The extra include path works around the runtime's FPGA build omitting the path
to the unconditionally included `io_mux.h` header.

## 4. Open the UART

The onboard Digilent UART runs at 115200 baud, 8 data bits, no parity, and one
stop bit. Find its stable device path:

```shell
python3 -m serial.tools.list_ports -v
```

Open the port before starting the application so its first output is captured:

```shell
export UART_PORT=/dev/serial/by-id/usb-Digilent_Digilent_USB_Device_SERIAL-if01-port0
python3 -m serial.tools.miniterm "$UART_PORT" 115200 --raw --dtr 0 --rts 0
```

Replace `SERIAL` with the value reported on the local machine.

## 5. Start OpenOCD

In another terminal, start OpenOCD using the Olimex adapter connected to PMOD
JA:

```shell
"$OPENOCD/bin/openocd" \
  -f target/fpga/pulpissimo-arty/openocd-arty-olimex.cfg
```

A successful connection reports both TAPs, hart 992, and GDB port 3333:

```text
JTAG tap: riscv.unknown0 tap/device found: 0x5fffedb3
JTAG tap: riscv.cpu tap/device found: 0x50001db3
hart 992: XLEN=32
Listening on port 3333 for gdb connections
```

## 6. Load and Run the ELF

In a third terminal, load the application and resume the core:

```shell
"$PULP_RISCV_GCC_TOOLCHAIN/bin/riscv32-unknown-elf-gdb" \
  -ex "target remote localhost:3333" \
  -ex "monitor halt" \
  -ex load \
  -ex "set \$pc = _start" \
  -ex "monitor resume" \
  -ex detach \
  sw/regression_tests/hello/build/test/test
```

The UART terminal should display:

```text
Hello !
```

## Helper Script

After programming the FPGA and building an ELF, the board helper starts
OpenOCD, opens the UART, and loads the ELF with GDB:

```shell
UART_PORT="$UART_PORT" \
  target/fpga/pulpissimo-arty/elf_run.sh \
  sw/regression_tests/hello/build/test/test
```

Set `OPENOCD_CONFIG` to
`target/fpga/pulpissimo-arty/openocd-arty-hs2.cfg` when using a Digilent HS2
instead of the Olimex adapter.

## Troubleshooting

- `No JTAG Chain found` from the Olimex adapter usually means the FPGA has not
  been programmed yet or the PMOD JA wiring is incorrect.
- `usb_open() failed` usually means Vivado, OpenOCD, or another `xc3sprog`
  process has claimed the same FTDI interface.
- The onboard Digilent JTAG only programs the FPGA. OpenOCD must use the
  external adapter connected to PMOD JA.
- Use the PULP-compatible OpenOCD build. The expected core ID is `0x3e0`, which
  is hart 992.
- If UART output is missing, confirm an FPGA-mode build, the Digilent serial
  port, and 115200 baud.
