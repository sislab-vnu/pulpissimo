/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>

#include "gpio.h"
#include "pulp.h"

#define LED0_GPIO PAD_GPIO08
#define BLINK_COUNT 5U
#define BLINK_DELAY_MS 250U

static void delay_ms(unsigned int milliseconds)
{
  const unsigned int ticks_per_ms =
      (unsigned int)pi_freq_get(PI_FREQ_DOMAIN_FC) / 1000U;
  const unsigned int delay_ticks = ticks_per_ms * milliseconds;
  const unsigned int start = cpu_perf_get(CSR_PCER_CYCLES);

  while (cpu_perf_get(CSR_PCER_CYCLES) - start < delay_ticks) {
  }
}

int main(void)
{
  gpios_t gpio;

  gpio_init(&gpio);
  gpio_configure(&gpio, LED0_GPIO, GPIO_DIRECTION_INPUT);
  gpio_set(&gpio, LED0_GPIO, 0);
  gpio_configure(&gpio, LED0_GPIO, GPIO_DIRECTION_OUTPUT);
  io_mux_mode_set(LED0_GPIO, PAD_MODE_GPIO);

  cpu_perf_start();
  printf("Blinking Arty LED0 on GPIO %u\n", (unsigned int)LED0_GPIO);

  for (unsigned int i = 0; i < BLINK_COUNT; ++i) {
    gpio_set(&gpio, LED0_GPIO, 1);
    delay_ms(BLINK_DELAY_MS);
    gpio_set(&gpio, LED0_GPIO, 0);
    delay_ms(BLINK_DELAY_MS);
  }

  cpu_perf_stop();
  puts("GPIO blink complete");
  return 0;
}
