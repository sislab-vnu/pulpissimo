/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include <stdint.h>
#include <stdio.h>

#include "pulp.h"

#include "memory.h"

#define BUFFER_BYTES (16U * 1024U)
#define BUFFER_WORDS (BUFFER_BYTES / sizeof(uint32_t))
#define BENCHMARK_ITERATIONS 64U

static uint32_t source[BUFFER_WORDS];
static uint32_t destination[BUFFER_WORDS];

static void print_bandwidth(const char *name, unsigned int cycles,
                            unsigned int bytes)
{
  const uint64_t numerator =
      (uint64_t)bytes * pi_freq_get(PI_FREQ_DOMAIN_FC) * 100U;
  const uint64_t denominator = (uint64_t)cycles * 1024U * 1024U;
  const unsigned int hundredths = (unsigned int)(numerator / denominator);

  printf("%-10s %u cycles, %u.%02u MiB/s\n", name, cycles,
         hundredths / 100U, hundredths % 100U);
}

static int validate_write(void)
{
  const unsigned int final_iteration = BENCHMARK_ITERATIONS - 1U;

  for (unsigned int i = 0; i < BUFFER_WORDS; ++i) {
    if (destination[i] != ((i * 17U + 3U) ^ final_iteration)) {
      return 0;
    }
  }
  return 1;
}

static int validate_copy(void)
{
  for (unsigned int i = 0; i < BUFFER_WORDS; ++i) {
    if (destination[i] != source[i]) {
      return 0;
    }
  }
  return 1;
}

int main(void)
{
  unsigned int start;
  unsigned int write_cycles;
  unsigned int read_cycles;
  unsigned int copy_cycles;
  int write_valid;
  uint32_t expected_checksum = 0;
  uint32_t checksum;
  const unsigned int transferred_bytes =
      BUFFER_BYTES * BENCHMARK_ITERATIONS;

  for (unsigned int i = 0; i < BUFFER_WORDS; ++i) {
    source[i] = i * 17U + 3U;
    destination[i] = 0;
    expected_checksum += source[i];
  }
  expected_checksum *= BENCHMARK_ITERATIONS;

  cpu_perf_start();

  start = cpu_perf_get(CSR_PCER_CYCLES);
  memory_write(destination, BUFFER_WORDS, BENCHMARK_ITERATIONS);
  write_cycles = cpu_perf_get(CSR_PCER_CYCLES) - start;
  write_valid = validate_write();

  start = cpu_perf_get(CSR_PCER_CYCLES);
  checksum = memory_read(source, BUFFER_WORDS, BENCHMARK_ITERATIONS);
  read_cycles = cpu_perf_get(CSR_PCER_CYCLES) - start;

  start = cpu_perf_get(CSR_PCER_CYCLES);
  memory_copy(source, destination, BUFFER_WORDS, BENCHMARK_ITERATIONS);
  copy_cycles = cpu_perf_get(CSR_PCER_CYCLES) - start;

  cpu_perf_stop();

  puts("PULPissimo L2 memory benchmark");
  printf("Buffer     %u bytes x %u iterations\n", BUFFER_BYTES,
         BENCHMARK_ITERATIONS);
  print_bandwidth("Write", write_cycles, transferred_bytes);
  print_bandwidth("Read", read_cycles, transferred_bytes);
  print_bandwidth("Copy", copy_cycles, transferred_bytes);

  if (!write_valid || checksum != expected_checksum || !validate_copy()) {
    puts("Memory benchmark FAIL");
    return 1;
  }

  printf("Checksum   0x%08x\n", (unsigned int)checksum);
  puts("Memory benchmark PASS");
  return 0;
}
