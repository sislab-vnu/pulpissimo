/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include <stdio.h>

#include "pulp.h"

#define BLOCK_SIZE 32U

static uint8_t block[BLOCK_SIZE];

int main(void)
{
  puts("PULPissimo buffered UART");
  printf("Send exactly %u bytes; they will be returned as one block.\n",
         BLOCK_SIZE);

  uart_read(CONFIG_IO_UART_ITF, block, BLOCK_SIZE);
  uart_write(CONFIG_IO_UART_ITF, block, BLOCK_SIZE);

  puts("\nBuffered UART transfer PASS");
  return 0;
}
