#ifndef PULPISSIMO_EXAMPLE_CONV2D_H
#define PULPISSIMO_EXAMPLE_CONV2D_H

#include <stdint.h>

void conv5x5(const uint16_t *restrict input, uint16_t *restrict output,
             const uint16_t *restrict coefficients, int width, int height,
             unsigned int shift);

#endif
