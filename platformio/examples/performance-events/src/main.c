/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include <stdio.h>

#include "pulp.h"

#include "workload.h"

#define DATA_WORDS 256U
#define WORKLOAD_ITERATIONS 64U
#define MEMORY_ACCESSES (DATA_WORDS * WORKLOAD_ITERATIONS)
#define EXPECTED_CHECKSUM 0x8be1ec00U

typedef struct {
  const char *name;
  unsigned int id;
  unsigned int expected_count;
} event_t;

static const event_t events[] = {
    {"retired loads", CSR_PCER_LD, MEMORY_ACCESSES},
    {"retired stores", CSR_PCER_ST, MEMORY_ACCESSES},
    {"branches", CSR_PCER_BRANCH, 0},
    {"taken branches", CSR_PCER_TAKEN_BRANCH, 0},
    {"compressed instructions", CSR_PCER_COMP_INSTR, 0},
};

static uint32_t data[DATA_WORDS];

static void initialize_data(void)
{
  for (unsigned int i = 0; i < DATA_WORDS; ++i) {
    data[i] = i * 2654435761U + 17U;
  }
}

static int measure_event(const event_t *event, unsigned int *count,
                         uint32_t *checksum)
{
  const unsigned int mask = CSR_PCER_EVENT_MASK(event->id);
  unsigned int start;
  unsigned int end;
  uint32_t result;

  initialize_data();
  cpu_perf_stop();
  cpu_perf_start();
  cpu_perf_conf_events(mask);
  if (cpu_perf_conf_events_get() != mask) {
    cpu_perf_stop();
    return 0;
  }

  start = cpu_perf_get(3);
  result = event_workload(data, DATA_WORDS, WORKLOAD_ITERATIONS);
  end = cpu_perf_get(3);
  cpu_perf_stop();

  *checksum = result;
  *count = end - start;
  return 1;
}

int main(void)
{
  puts("CV32E40P configurable performance events");

  for (unsigned int i = 0; i < sizeof(events) / sizeof(events[0]); ++i) {
    uint32_t checksum;
    unsigned int count;

    if (!measure_event(&events[i], &count, &checksum)) {
      puts("Performance event configuration FAIL");
      return 1;
    }
    if (count == 0 || checksum != EXPECTED_CHECKSUM ||
        (events[i].expected_count != 0 &&
         count != events[i].expected_count)) {
      printf("%-24s FAIL\n", events[i].name);
      return 1;
    }
    printf("%-24s %u\n", events[i].name, count);
  }

  printf("Checksum                 0x%08x\n",
         (unsigned int)EXPECTED_CHECKSUM);
  puts("Performance event sweep PASS");
  return 0;
}
