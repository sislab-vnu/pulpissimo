/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include <stdio.h>

#include "pulp.h"

#include "conv2d.h"

#ifndef BENCHMARK_ITERATIONS
#define BENCHMARK_ITERATIONS 1000U
#endif

#define IMAGE_SIZE 10
#define KERNEL_SIZE 5
#define OUTPUT_WIDTH (IMAGE_SIZE - KERNEL_SIZE + 1)
#define OUTPUTS_PER_ITERATION (OUTPUT_WIDTH * OUTPUT_WIDTH)
#define MACS_PER_ITERATION (OUTPUTS_PER_ITERATION * KERNEL_SIZE * KERNEL_SIZE)

static const uint16_t coefficients[KERNEL_SIZE * KERNEL_SIZE] = {
    1,  4,  6,  4,  1,
    4, 16, 24, 16,  4,
    6, 24, 36, 24,  6,
    4, 16, 24, 16,  4,
    1,  4,  6,  4,  1,
};

static const uint16_t expected[IMAGE_SIZE * IMAGE_SIZE] = {
    0, 0,   0,   0,   0,   0,   0,   0,   0, 0,
    0, 0,   0,   0,   0,   0,   0,   0,   0, 0,
    0, 0, 114, 128, 126, 107,  96, 104,   0, 0,
    0, 0, 118, 127, 119, 107, 106, 115,   0, 0,
    0, 0, 120, 130, 119, 106, 105, 113,   0, 0,
    0, 0, 112, 124, 120, 110, 107, 111,   0, 0,
    0, 0, 109, 111, 114, 118, 121, 120,   0, 0,
    0, 0, 118, 110, 112, 127, 136, 133,   0, 0,
    0, 0,   0,   0,   0,   0,   0,   0,   0, 0,
    0, 0,   0,   0,   0,   0,   0,   0,   0, 0,
};

static uint16_t input[IMAGE_SIZE * IMAGE_SIZE];
static uint16_t output[IMAGE_SIZE * IMAGE_SIZE];

static void print_ratio(const char *label, unsigned int numerator,
                        unsigned int denominator)
{
  unsigned int integer;
  unsigned int fractional;
  uint64_t scaled_remainder;

  if (denominator == 0) {
    printf("%-18s n/a\n", label);
    return;
  }

  integer = numerator / denominator;
  scaled_remainder = (uint64_t)(numerator % denominator) * 100U;
  fractional = (unsigned int)((scaled_remainder + denominator / 2U) /
                              denominator);
  if (fractional == 100U) {
    ++integer;
    fractional = 0;
  }
  printf("%-18s %u.%02u\n", label, integer, fractional);
}

static int validate_output(void)
{
  for (unsigned int i = 0; i < IMAGE_SIZE * IMAGE_SIZE; ++i) {
    if (output[i] != expected[i]) {
      printf("Mismatch at %u: got %u, expected %u\n", i,
             (unsigned int)output[i], (unsigned int)expected[i]);
      return 0;
    }
  }
  return 1;
}

int main(void)
{
  unsigned int cycle_start;
  unsigned int instruction_start;
  unsigned int load_start;
  unsigned int cycle_end;
  unsigned int instruction_end;
  unsigned int load_end;
  unsigned int cycles;
  unsigned int instructions;
  unsigned int loads;
  const unsigned int event_mask = CSR_PCER_EVENT_MASK(CSR_PCER_LD);
  const unsigned int total_outputs =
      BENCHMARK_ITERATIONS * OUTPUTS_PER_ITERATION;
  const unsigned int total_macs =
      BENCHMARK_ITERATIONS * MACS_PER_ITERATION;

  for (unsigned int i = 0; i < IMAGE_SIZE * IMAGE_SIZE; ++i) {
    input[i] = (uint16_t)((i * i + 3U * i + 7U) % 251U);
    output[i] = 0;
  }

  conv5x5(input, output, coefficients, IMAGE_SIZE, IMAGE_SIZE, 8);

  cpu_perf_stop();
  cpu_perf_start();
  cpu_perf_conf_events(event_mask);
  if (cpu_perf_conf_events_get() != event_mask) {
    cpu_perf_stop();
    puts("Could not configure the performance event counter");
    return 1;
  }

  load_start = cpu_perf_get(3);
  cycle_start = cpu_perf_get(0);
  instruction_start = cpu_perf_get(2);

  for (unsigned int i = 0; i < BENCHMARK_ITERATIONS; ++i) {
    conv5x5(input, output, coefficients, IMAGE_SIZE, IMAGE_SIZE, 8);
  }

  cycle_end = cpu_perf_get(0);
  instruction_end = cpu_perf_get(2);
  load_end = cpu_perf_get(3);
  cpu_perf_stop();

  cycles = cycle_end - cycle_start;
  instructions = instruction_end - instruction_start;
  loads = load_end - load_start;

  puts("PULPissimo CV32E40P convolution benchmark");
  printf("Core clock         %u Hz\n",
         (unsigned int)pi_freq_get(PI_FREQ_DOMAIN_FC));
  printf("Iterations         %u\n", (unsigned int)BENCHMARK_ITERATIONS);
  printf("Outputs            %u\n", total_outputs);
  printf("Multiply-accumulate %u\n", total_macs);
  printf("Cycles             %u\n", cycles);
  printf("Instructions       %u\n", instructions);
  printf("Retired loads      %u\n", loads);
  print_ratio("CPI", cycles, instructions);
  print_ratio("Cycles/output", cycles, total_outputs);
  print_ratio("MACs/cycle", total_macs, cycles);

  if (!validate_output()) {
    puts("Result             FAIL");
    return 1;
  }

  puts("Result             PASS");
  return 0;
}
