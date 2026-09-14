/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "memory.h"

void memory_write(uint32_t *destination, unsigned int words,
                  unsigned int iterations)
{
  for (unsigned int iteration = 0; iteration < iterations; ++iteration) {
    for (unsigned int i = 0; i < words; ++i) {
      destination[i] = (i * 17U + 3U) ^ iteration;
    }
  }
}

uint32_t memory_read(const uint32_t *source, unsigned int words,
                     unsigned int iterations)
{
  uint32_t checksum = 0;

  for (unsigned int iteration = 0; iteration < iterations; ++iteration) {
    for (unsigned int i = 0; i < words; ++i) {
      checksum += source[i];
    }
  }
  return checksum;
}

void memory_copy(const uint32_t *source, uint32_t *destination,
                 unsigned int words, unsigned int iterations)
{
  for (unsigned int iteration = 0; iteration < iterations; ++iteration) {
    for (unsigned int i = 0; i < words; ++i) {
      destination[i] = source[i];
    }
  }
}
