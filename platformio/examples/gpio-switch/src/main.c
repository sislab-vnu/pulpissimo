/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>

#include "gpio.h"
#include "pulp.h"

#define LED0_GPIO PAD_GPIO08
#define SWITCH0_GPIO PAD_GPIO12

int main(void)
{
  gpios_t gpio;
  unsigned int previous = 2U;

  gpio_init(&gpio);
  gpio_configure(&gpio, LED0_GPIO, GPIO_DIRECTION_INPUT);
  gpio_configure(&gpio, SWITCH0_GPIO, GPIO_DIRECTION_INPUT);
  gpio_set(&gpio, LED0_GPIO, 0);
  gpio_configure(&gpio, LED0_GPIO, GPIO_DIRECTION_OUTPUT);
  io_mux_mode_set(SWITCH0_GPIO, PAD_MODE_GPIO);
  io_mux_mode_set(LED0_GPIO, PAD_MODE_GPIO);

  puts("Mirroring Arty SW0 to LED0; reset or upload another app to stop.");

  while (1) {
    const unsigned int current = gpio_get(&gpio, SWITCH0_GPIO);

    gpio_set(&gpio, LED0_GPIO, current);
    if (current != previous) {
      printf("SW0=%u LED0=%u\n", current, current);
      previous = current;
    }
  }
}
