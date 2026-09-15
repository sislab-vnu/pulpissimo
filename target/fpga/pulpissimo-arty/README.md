# PULPissimo on the Digilent Arty A7 Boards
[\[Documentation Arty A7 (35T/100T)\]](https://digilent.com/reference/programmable-logic/arty-a7/reference-manual)

See [Arty A7 FPGA and Default RTL Simulation](FPGA_VS_SIMULATION.md) for the
platform differences that affect clocks, software, program loading, peripherals,
and verification results.

See [Running PULPissimo on Arty A7-100T](RUN_ARTY_A7_100T.md) for the complete,
verified FPGA programming, OpenOCD, GDB, and UART workflow.

## Bitstream Generation
The Makefile can handle all revisions of the Arty A7 board. You can generate the Bitfile for the desired revision by running
```Shell
make arty rev=[artyA7-35T|artyA7-100T]
```
in the `fpga` folder. The generated bitstream will be copied into the fpga folder.

## Bitstream Download
To download this bitstream into the FPGA connect the PROG USB header, turn the board on and run
```Shell
make -C pulpissimo-arty download rev=artyA7-100T
```

Alternatively, program the volatile FPGA configuration through the onboard
Digilent JTAG interface with `xc3sprog`:

```Shell
$XC3SPROG -c nexys4 pulpissimo_arty.bit
```

Program the FPGA before starting OpenOCD. The onboard JTAG interface configures
the FPGA; it does not connect to the PULPissimo JTAG port.

## Default SoC and Core Frequencies

By default the clock generating IPs are synthesized to provide the following frequencies to PULPissimo:

| Clock Domain         | Default Frequency on Arty A7 board |
|----------------------|------------------------------------|
| SoC/Core Frequency   | 10 MHz                             |
| Peripheral Frequency | 5 MHz                              |


## Peripherals
PULPissimo is connected to the following board peripherals:


| PULPissimo Pin | Mapped Board Peripheral |
|----------------|-------------------------|
| `SPIM0`        | PMOD C Pins 1-8         |
| `SDIO`         | PMOD D                  |
| `I2C`          | SCL/SDA (ChipKit_IO)    |
| GPIO pads      | PMOD B Pins 1-4         |
| `JTAG`         | PMOD A Pins 1-4         |
| `spim_csn1`    | LED0                    |
| `cam_pclk`     | LED1                    |
| `cam_hsync`    | LED2                    |
| `cam_data0`    | LED3                    |
| `cam_data1`    | Switch 0                |
| `cam_data2`    | Switch 1                |
| `cam_data3`    | Center button           |
| `cam_data4`    | Down button             |
| `cam_data5`    | Left button             |
| `cam_data6`    | Right button            |
| `cam_data7`    | Up button               |

For more information consult board constraint files.

The current uDMA configuration does not instantiate I2S. The PMOD B signals
retain their legacy I2S-oriented wrapper names but are available as muxed GPIO
pads.

### UART
PULPissimo's UART port is mapped to the onboard FTDI FT2232H USB-UART bridge and thus accessible through the UART micro-USB connector (J6). The baud rate is 115200.

List the serial ports and open the Digilent port with PySerial miniterm:

```Shell
python3 -m serial.tools.list_ports -v
python3 -m serial.tools.miniterm "$UART_PORT" 115200 --raw --dtr 0 --rts 0
```

### QSPI-Flash
The Arty A7-100T onboard configuration flash can hold both the FPGA image and a
PULP flash-v2 application. The dedicated build leaves the normal `make arty`
mapping unchanged and remaps SPIM0 from PMOD C to the onboard flash. The flash
layout is:

| Address range | Contents |
|---------------|----------|
| `0x00000000` to `0x003FFFFF` | FPGA configuration |
| `0x00400000` onward | PULP application |

Build the combined MCS image from the `target/fpga` directory. `APP_ELF` should
be an absolute path to an FPGA-mode executable:

```Shell
make arty_flash rev=artyA7-100T APP_ELF=/absolute/path/to/application.elf
```

Program and verify the onboard flash with:

```Shell
make program_arty_flash rev=artyA7-100T \
  APP_ELF=/absolute/path/to/application.elf
```

This erases the board's existing persistent FPGA image. The default
configuration-memory part is the Spansion/Infineon S25FL128S. For a board with
the Micron N25Q128A, add
`CFGMEM_PART=mt25ql128-spi-x1_x2_x4`. Use `HW_SERVER_URL` when Vivado's hardware
server is not at `TCP:localhost:3121`, and `HW_TARGET` when that server exposes
multiple targets.

After programming, power-cycle the board or use Vivado's `boot_hw_device` to
configure the FPGA and start the application from flash. UART output remains at
115200 baud.

### Reset Button
The RESET button (C12) resets the RISC-V CPU.

### JTAG
Although the Arty board has an on-board JTAG programmer, it is not possible to connect it to the PULPissimo JTAG port.
Therefore you need an external JTAG programmer device connected to PMOD A. The pinout is as follow:

| JTAG Signal | PMOD Pin |
|-------------|----------|
| TMS         | JA1      |
| TDI         | JA2      |
| TDO         | JA3      |
| TCK         | JA4      |
| GND         | JA5      |
| VCC (trgt)  | JA6      |

The directory holding this README contains OpenOCD configuration files for tested adapters.
The commands below are to be executed from within the `fpga` directory.

#### Olimex ARM-USB-OCD-H

```Shell
$OPENOCD/bin/openocd -f pulpissimo-arty/openocd-arty-olimex.cfg
```

#### Digilent HS-2

If you have Vivado running remember to disconnect the target and close HW Manager before attempting to use OpenOCD.


```Shell
$OPENOCD/bin/openocd -f pulpissimo-arty/openocd-arty-hs2.cfg
```

### Loading Software

With OpenOCD running, load an FPGA-mode ELF using the PULP RISC-V GDB:

```Shell
$PULP_RISCV_GCC_TOOLCHAIN/bin/riscv32-unknown-elf-gdb \
  -ex "target remote localhost:3333" \
  -ex "monitor halt" \
  -ex load \
  -ex "set \$pc = _start" \
  -ex "monitor resume" \
  -ex detach \
  PATH_TO_ELF
```

For example, build the hello application from the repository root with UART
output enabled for FPGA operation:

```Shell
export PULPRT_CONFIG_CFLAGS="-I$PWD/sw/pulp-runtime/drivers/pulpissimo/rtl_sim/io_mux/include"
source sw/pulp-runtime/configs/pulpissimo_cv32_zfinx.sh
make -C sw/regression_tests/hello clean all platform=fpga
```

The extra include path works around the runtime's FPGA build omitting the path
to the unconditionally included `io_mux.h` header.

### PlatformIO

Repository-local PlatformIO IDE and CLI support is available under
[`platformio/`](../../../platformio/README.md). The included example projects
support building, bitstream programming with the onboard Digilent adapter,
firmware upload and debugging with the Olimex adapter, and UART monitoring.
