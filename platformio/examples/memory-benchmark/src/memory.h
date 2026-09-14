#ifndef PULPISSIMO_EXAMPLE_MEMORY_H
#define PULPISSIMO_EXAMPLE_MEMORY_H

#include <stdint.h>

void memory_write(uint32_t *destination, unsigned int words,
                  unsigned int iterations);
uint32_t memory_read(const uint32_t *source, unsigned int words,
                     unsigned int iterations);
void memory_copy(const uint32_t *source, uint32_t *destination,
                 unsigned int words, unsigned int iterations);

#endif
