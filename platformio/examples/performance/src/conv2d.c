/*
 * Copyright (C) 2018 ETH Zurich and University of Bologna
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "conv2d.h"

void conv5x5(const uint16_t *restrict input, uint16_t *restrict output,
             const uint16_t *restrict coefficients, int width, int height,
             unsigned int shift)
{
  const int radius = 2;

  for (int y = radius; y < height - radius; ++y) {
    for (int x = radius; x < width - radius; ++x) {
      uint32_t sum = 0;
      int coefficient = 0;

      for (int kernel_y = -radius; kernel_y <= radius; ++kernel_y) {
        const int row = (y + kernel_y) * width + x - radius;

        for (int kernel_x = 0; kernel_x < 5; ++kernel_x) {
          sum += coefficients[coefficient++] * input[row + kernel_x];
        }
      }
      output[y * width + x] = (uint16_t)(sum >> shift);
    }
  }
}
