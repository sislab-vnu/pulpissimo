/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "workload.h"

uint32_t event_workload(uint32_t *data, unsigned int words,
                        unsigned int iterations)
{
  uint32_t checksum = 0;

  for (unsigned int iteration = 0; iteration < iterations; ++iteration) {
    for (unsigned int i = 0; i < words; ++i) {
      uint32_t value = data[i];

      if (value & 1U) {
        value ^= 0x9e3779b9U;
      } else {
        value += iteration + i;
      }
      data[i] = value;
      checksum += value;
    }
  }
  return checksum;
}
