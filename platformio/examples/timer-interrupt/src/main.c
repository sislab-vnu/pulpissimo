/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdio.h>

#include "pulp.h"

#define TIMER_IRQ ARCHI_FC_EVT_TIMER0_LO
#define TIMER_IRQ_MASK (1U << TIMER_IRQ)
#define TIMER_ADDR ARCHI_FC_TIMER_ADDR
#define TIMER_PERIOD_MS 100U
#define TIMER_TICKS 5U

static volatile unsigned int tick_count;

static void __attribute__((interrupt("machine"))) timer_handler(void)
{
  rt_irq_clr(TIMER_IRQ_MASK);
  ++tick_count;
  if (tick_count == TIMER_TICKS) {
    timer_conf_set(TIMER_ADDR, 0);
  }
}

int main(void)
{
  const unsigned int period_cycles =
      (unsigned int)pi_freq_get(PI_FREQ_DOMAIN_FC) / 1000U * TIMER_PERIOD_MS;

  puts("Starting periodic timer interrupts");

  rt_irq_mask_clr(TIMER_IRQ_MASK);
  rt_irq_clr(TIMER_IRQ_MASK);
  rt_irq_set_handler(TIMER_IRQ, timer_handler);
  timer_count_set(TIMER_ADDR, 0);
  timer_cmp_set(TIMER_ADDR, period_cycles);
  rt_irq_mask_set(TIMER_IRQ_MASK);
  timer_conf_set(TIMER_ADDR,
                 TIMER_CFG_LO_ENABLE_MASK | TIMER_CFG_LO_RESET_MASK |
                     TIMER_CFG_LO_IRQEN_MASK | TIMER_CFG_LO_MODE_MASK);

  while (tick_count < TIMER_TICKS) {
    rt_irq_wait_for_interrupt();
  }

  rt_irq_mask_clr(TIMER_IRQ_MASK);
  printf("Received %u timer interrupts\n", tick_count);
  puts("Timer interrupt test PASS");
  return 0;
}
