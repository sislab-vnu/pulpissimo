/*
 * Copyright 2026 PULP Platform contributors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

#include "common/bitfield.h"

/* Provide the external definitions required by the header's C inline API. */
extern inline uint32_t bitfield_field32_read(uint32_t bitfield,
                                             bitfield_field32_t field);
extern inline uint32_t bitfield_field32_write(uint32_t bitfield,
                                              bitfield_field32_t field,
                                              uint32_t value);
extern inline bitfield_field32_t bitfield_bit32_to_field32(
    bitfield_bit32_index_t bit_index);
extern inline bool bitfield_bit32_read(uint32_t bitfield,
                                       bitfield_bit32_index_t bit_index);
extern inline uint32_t bitfield_bit32_write(
    uint32_t bitfield, bitfield_bit32_index_t bit_index, bool value);
extern inline int32_t bitfield_find_first_set32(int32_t bitfield);
extern inline int32_t bitfield_count_leading_zeroes32(uint32_t bitfield);
extern inline int32_t bitfield_count_trailing_zeroes32(uint32_t bitfield);
extern inline int32_t bitfield_popcount32(uint32_t bitfield);
extern inline int32_t bitfield_parity32(uint32_t bitfield);
extern inline uint32_t bitfield_byteswap32(uint32_t bitfield);
