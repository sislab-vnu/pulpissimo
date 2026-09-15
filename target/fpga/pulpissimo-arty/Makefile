include fpga-settings.mk

PROJECT:=pulpissimo-$(BOARD)
VIVADO ?= vivado
PULPISSIMO_ROOT := $(abspath ../../..)
BOOTCODE_DIR := $(PULPISSIMO_ROOT)/sw/bootcode
FLASH_DIR := $(CURDIR)/flash
FLASH_IMAGE_OFFSET ?= 0x00400000
CFGMEM_PART ?= s25fl128sxxxxxx0-spi-x1_x2_x4
HW_SERVER_URL ?= TCP:localhost:3121
ONBOARD_BITSTREAM := $(CURDIR)/$(PROJECT).runs/impl_1/xilinx_pulpissimo.bit
ONBOARD_APPLICATION := $(FLASH_DIR)/pulpissimo-arty-application.bin
ONBOARD_IMAGE := $(FLASH_DIR)/pulpissimo-arty-onboard.mcs

.DEFAULT_GOAL:=help

.PHONY: help all gui ips clean-ips clk clean-clk clean \
	onboard-flash-bootrom onboard-flash-bitstream onboard-flash-application \
	onboard-flash-image program-onboard-flash

#Make sure BENDER environment variable is available for subprocesses in Make
export BENDER
export HW_SERVER_URL

## @param FLASH_IMAGE_OFFSET=0x00400000 Application offset in the onboard flash
## @param CFGMEM_PART=s25fl128sxxxxxx0-spi-x1_x2_x4 Vivado configuration-memory part; use mt25ql128-spi-x1_x2_x4 for Micron-equipped boards
## @param HW_SERVER_URL=TCP:localhost:3121 Vivado hardware-server URL
## @param HW_TARGET= Vivado hardware-target name when the server exposes multiple targets

all: ips ## Generate the bitstream for pulpissimo with vivado in batch mode. The vivado invocation command may be overriden with the env variable VIVADO.
	$(VIVADO) -mode batch -source tcl/run.tcl

gui: ips ## Generates the bitstream for pulpissimo with vivado in GUI mode. The vivado invocation command may be overriden with the env variable VIVADO.
	$(VIVADO) -mode gui -source tcl/run.tcl &

onboard-flash-bootrom: ## Generate the Arty boot ROM for an application at FLASH_IMAGE_OFFSET
	$(MAKE) -C $(BOOTCODE_DIR) build/arty/fpga_autogen_rom.sv \
		FLASH_IMAGE_OFFSET=$(FLASH_IMAGE_OFFSET)

onboard-flash-bitstream: export ARTY_ONBOARD_FLASH=1
onboard-flash-bitstream: ips onboard-flash-bootrom ## Build the Arty A7-100T onboard-flash bitstream
	@test "$(rev)" = "artyA7-100T" || \
		{ echo "Onboard flash supports only rev=artyA7-100T"; exit 2; }
	$(VIVADO) -mode batch -source tcl/run.tcl

onboard-flash-application: ## Convert APP_ELF to a PULP flash-v2 application image
	@test -n "$(APP_ELF)" || { echo "APP_ELF is required"; exit 2; }
	@test -f "$(APP_ELF)" || { echo "APP_ELF does not exist: $(APP_ELF)"; exit 2; }
	@mkdir -p $(FLASH_DIR)
	$(PULPISSIMO_ROOT)/sw/pulp-runtime/bin/plp_mkflash \
		--flash-boot-binary="$(abspath $(APP_ELF))" \
		--flash-type=spi \
		--raw="$(ONBOARD_APPLICATION)"

onboard-flash-image: onboard-flash-application onboard-flash-bitstream ## Build an MCS with FPGA and application images
	$(VIVADO) -mode batch -source tcl/write_cfgmem.tcl -tclargs \
		"$(ONBOARD_BITSTREAM)" "$(ONBOARD_APPLICATION)" \
		"$(ONBOARD_IMAGE)" "$(FLASH_IMAGE_OFFSET)"

program-onboard-flash: onboard-flash-image ## Program and verify the onboard flash through Vivado Hardware Manager
	$(VIVADO) -mode batch -source tcl/program_cfgmem.tcl -tclargs \
		"$(ONBOARD_IMAGE)" "$(CFGMEM_PART)"

ips: clk ## Synthesizes necessary xilinx IP

clean-ips: clean-clk ## Clean all IPs

clk: ## Synthesizes the Xilinx Clocking Manager IPs
	$(MAKE) -C ips/xilinx_clk_mngr all
	$(MAKE) -C ips/xilinx_slow_clk_mngr all

clean-clk: ## Removes all Clocking Wizard IP outputs
	$(MAKE) -C ips/xilinx_clk_mngr clean
	$(MAKE) -C ips/xilinx_slow_clk_mngr clean

clean: ## Removes all bitstreams, *.log files and vivado related files (rm -rf vivado*)
	rm -rf ${PROJECT}.*[^'bit']
	rm -rf ${PROJECT}.*[^'bin']
	rm -rf *.log
	rm -rf vivado*
	rm -rf flash

download: ## Download the bitstream into the FPGA
	$(VIVADO) -mode batch -source tcl/download_bitstream.tcl -tclargs $(PROJECT).runs/impl_1/xilinx_pulpissimo.bit pulpissimo_$(BOARD).bit

help:
	@grep -E -h '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
