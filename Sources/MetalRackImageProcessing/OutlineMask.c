#include "MetalRackImageProcessing.h"
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>

// Exact binary silhouette dilation, minus the silhouette itself. Disk distances
// are measured in capture pixels; no alpha averaging or blur is introduced.
static void MRCreateOutlineMaskFallback(const uint8_t *rgba, int width, int height,
                             int radius, uint8_t *result) {
    memset(result, 0, (size_t)width * height * 4);
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        if (rgba[((size_t)y * width + x) * 4 + 3] >= 128) continue;
        int found = 0;
        for (int dy = -radius; dy <= radius && !found; ++dy) {
            int sy = y + dy;
            if (sy < 0 || sy >= height) continue;
            for (int dx = -radius; dx <= radius; ++dx) {
                int sx = x + dx;
                if (sx < 0 || sx >= width || dx * dx + dy * dy > radius * radius) continue;
                if (rgba[((size_t)sy * width + sx) * 4 + 3] >= 128) { found = 1; break; }
            }
        }
        if (found) memset(result + ((size_t)y * width + x) * 4, 255, 4);
    }
}

// Find the nearest solid pixel horizontally on each source row. A destination
// lies in the exact disk dilation iff one row's nearest pixel satisfies
// horizontalDistance^2 + verticalDistance^2 <= radius^2. This replaces the
// radius-squared neighborhood scan with two linear sweeps and one row scan.
void MRCreateOutlineMask(const uint8_t *rgba, int width, int height,
                         int radius, uint8_t *result) {
    const size_t count = (size_t)width * height;
    memset(result, 0, count * 4);
    if (radius <= 0) return;
    unsigned coverage = 0;
    for (size_t i = 0; i < count && coverage != 3; ++i)
        coverage |= rgba[i*4+3] >= 128 ? 1u : 2u;
    if (coverage != 3) return; // Empty and completely solid canvases have no ring.
    int *nearest = malloc(count * sizeof(*nearest));
    if (!nearest) {
        MRCreateOutlineMaskFallback(rgba, width, height, radius, result);
        return;
    }
    for (int y = 0; y < height; ++y) {
        size_t row = (size_t)y * width;
        int distance = INT_MAX;
        for (int x = 0; x < width; ++x) {
            if (rgba[(row+x)*4+3] >= 128) distance = 0;
            else if (distance != INT_MAX) ++distance;
            nearest[row+x] = distance;
        }
        distance = INT_MAX;
        for (int x = width-1; x >= 0; --x) {
            if (rgba[(row+x)*4+3] >= 128) distance = 0;
            else if (distance != INT_MAX) ++distance;
            if (distance < nearest[row+x]) nearest[row+x] = distance;
        }
    }
    const int64_t radiusSquared = (int64_t)radius * radius;
    for (int y = 0; y < height; ++y) for (int x = 0; x < width; ++x) {
        size_t pixel = (size_t)y * width + x;
        if (rgba[pixel*4+3] >= 128) continue;
        int first = radius < y ? y-radius : 0;
        int last = radius < height-1-y ? y+radius : height-1;
        for (int sy = first; sy <= last; ++sy) {
            int dx = nearest[(size_t)sy*width+x];
            if (dx == INT_MAX) continue; // An empty source row has no seed.
            int64_t dy = (int64_t)sy-y;
            if ((int64_t)dx*dx + dy*dy <= radiusSquared) {
                memset(result+pixel*4, 255, 4);
                break;
            }
        }
    }
    free(nearest);
}
