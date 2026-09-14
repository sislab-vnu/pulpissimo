/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include <stdio.h>

#include "pulp.h"

int main(void)
{
  uint8_t character;

  puts("PULPissimo UART echo");
  puts("Type characters to echo; enter q to quit.");

  do {
    uart_read(CONFIG_IO_UART_ITF, &character, 1);
    if (character == '\r') {
      character = '\n';
    }
    putchar(character);
  } while (character != 'q');

  puts("\nUART echo complete");
  return 0;
}
