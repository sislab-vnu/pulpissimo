# PULPissimo on the Digilent Arty A7 Boards
[\[Documentation Arty A7 (35T/100T)\]](https://digilent.com/reference/programmable-logic/arty-a7/reference-manual)

## Bitstream Generation
The Makefile can handle all revisions of the Arty A7 board. You can generate the Bitfile for the desired revision by running
```Shell
make arty rev=[artyA7-35T|artyA7-100T]
```
in the `fpga` folder. The generated bitstream will be copied into the fpga folder.

## Bitstream Download
To download this bitstream into the FPGA connect the PROG USB header, turn the board on and run
```Shell
make -C pulpissimo-arty download
```

## Default SoC and Core Frequencies

By default the clock generating IPs are synthesized to provide the following frequencies to PULPissimo:

| Clock Domain   | Default Frequency on Arty A7 board |
|----------------|------------------------------------|
| Core Frequency | 10 MHz                             |
| SoC Frequency  | 5 MHz                              |


## Peripherals
PULPissimo is connected to the following board peripherals:


| PULPissimo Pin | Mapped Board Peripheral |
|----------------|-------------------------|
| `SPIM0`        | PMOD C Pins 1-8         |
| `SDIO`         | PMOD D                  |
| `I2C`          | SCL/SDA (ChipKit_IO)    |
| `I2S`          | PMOD B Pins 7-10        |
| `JTAG`         | PMOD A Pins 1-4         |
| `spim_csn1`    | LED0                    |
| `cam_pclk`     | LED1                    |
| `cam_hsync`    | LED2                    |
| `cam_data0`    | LED3                    |
| `cam_data1`    | Switch 1                |
| `cam_data2`    | Switch 2                |
| `cam_data3`    | Switch 0                |
| `cam_data4`    | Button 1                |
| `cam_data5`    | Button 2                |
| `cam_data6`    | Button 3                |
| `cam_data7`    | Button 4                |

For more information consult board constraint files.

### UART
PULPissimo's UART port is mapped to the onboard FTDI FT2232H USB-UART bridge and thus accessible through the UART micro-USB connector (J6).

### QSPI-Flash
Arty boards have 3 types of Flash memory depending on the PCB revision which can be used for configuration of the FPGA:
- Micron N25Q128A
- Spansion/Infineon S25FL128SAG[M|N]FI00
- Spansion/Infineon S25FL127SABMFx00

It also can be used for user applications. 

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

The directory holding this README contains a OpenOCD configuration file for a tested adapter.
The commands below are to be executed from within the `fpga` directory.

#### Digilent HS-2

If you have Vivado running remember to disconnect the target and close HW Manager before attempting to use OpenOCD.


```Shell
$OPENOCD/bin/openocd -f pulpissimo-nexys4/openocd-nexys-hs2.cfg
```

