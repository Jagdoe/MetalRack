#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// Binary white outline outside an RGBA8 silhouette. Buffers contain width*height*4
// bytes and must not overlap. Alpha >= 128 is solid; radius is in source pixels.
// The output uses the input row order and includes contours around internal holes.
void MRCreateOutlineMask(const uint8_t *rgba, int width, int height,
                         int radius, uint8_t *result);
#ifdef __cplusplus
}
#endif
