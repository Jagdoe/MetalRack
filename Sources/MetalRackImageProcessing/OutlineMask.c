#include "MetalRackImageProcessing.h"
#include <stddef.h>
#include <string.h>

// Exact binary silhouette dilation, minus the silhouette itself. Disk distances
// are measured in capture pixels; no alpha averaging or blur is introduced.
void MRCreateOutlineMask(const uint8_t *rgba, int width, int height,
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
