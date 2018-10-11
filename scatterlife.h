
#define UNIVERSE_WIDTH 2048
#define UNIVERSE_HEIGHT 2048

typedef struct {
  unsigned int bound[6];
  unsigned int unbound[6];
} Cell;

typedef Cell Universe[UNIVERSE_WIDTH][UNIVERSE_HEIGHT];

#define RASTER_UPSAMPLE 1
#define RASTER_WIDTH (RASTER_UPSAMPLE * UNIVERSE_WIDTH)
#define RASTER_HEIGHT (RASTER_UPSAMPLE * UNIVERSE_HEIGHT)
typedef unsigned int UniImg[RASTER_WIDTH][RASTER_HEIGHT];

#define INITIAL_PARTICLE_COUNT (UNIVERSE_WIDTH*16)