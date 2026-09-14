/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "io_mux.h"
#include "pulp.h"

#define FPGA_PAD_CFG_RX_EN_BIT 1U
#define FPGA_PAD_CFG_TX_EN_BIT 2U

void io_mux_config_set(io_mux_pad_e pad, io_mux_cfg_t const *cfg)
{
  const uint32_t addr = ARCHI_PAD_CFG_ADDR +
                        pad * IO_MUX_PAD_REG_SEPARATION +
                        IO_MUX_PAD_CFG_REG_OFFSET;
  uint32_t reg = pulp_read32(addr);

  /* FPGA pads have no software-controlled pull resistor. */
  reg = bitfield_bit32_write(reg, FPGA_PAD_CFG_RX_EN_BIT, cfg->rx_en != 0);
  reg = bitfield_bit32_write(reg, FPGA_PAD_CFG_TX_EN_BIT, cfg->tx_en != 0);
  pulp_write32(addr, reg);
}

void io_mux_config_get(io_mux_pad_e pad, io_mux_cfg_t *cfg)
{
  const uint32_t addr = ARCHI_PAD_CFG_ADDR +
                        pad * IO_MUX_PAD_REG_SEPARATION +
                        IO_MUX_PAD_CFG_REG_OFFSET;
  const uint32_t reg = pulp_read32(addr);

  cfg->pull_cfg = IO_MUX_NO_PULL;
  cfg->rx_en = bitfield_bit32_read(reg, FPGA_PAD_CFG_RX_EN_BIT);
  cfg->tx_en = bitfield_bit32_read(reg, FPGA_PAD_CFG_TX_EN_BIT);
}

void io_mux_mode_set(io_mux_pad_e pad, io_mux_mode_e mode)
{
  const uint32_t addr = ARCHI_PAD_CFG_ADDR +
                        pad * IO_MUX_PAD_REG_SEPARATION +
                        IO_MUX_PAD_MUX_SEL_REG_OFFSET;
  uint32_t reg = pulp_read32(addr);

  reg = bitfield_field32_write(
      reg,
      PULPISSIMO_PADFRAME_ALL_PADS_CONFIG_PAD_IO00_MUX_SEL_PAD_IO00_MUX_SEL_FIELD,
      mode);
  pulp_write32(addr, reg);
}

io_mux_mode_e io_mux_mode_get(io_mux_pad_e pad)
{
  const uint32_t addr = ARCHI_PAD_CFG_ADDR +
                        pad * IO_MUX_PAD_REG_SEPARATION +
                        IO_MUX_PAD_MUX_SEL_REG_OFFSET;
  const uint32_t reg = pulp_read32(addr);

  return bitfield_field32_read(
      reg,
      PULPISSIMO_PADFRAME_ALL_PADS_CONFIG_PAD_IO00_MUX_SEL_PAD_IO00_MUX_SEL_FIELD);
}
