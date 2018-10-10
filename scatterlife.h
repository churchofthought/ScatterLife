
#define UNIVERSE_WIDTH 4096
#define UNIVERSE_HEIGHT 4096*1/3

typedef struct {
  unsigned int bound[6];
  unsigned int unbound[6];
} Cell;

typedef Cell Universe[UNIVERSE_WIDTH][UNIVERSE_HEIGHT];

#define RASTER_UPSAMPLE 1
#define RASTER_WIDTH RASTER_UPSAMPLE * UNIVERSE_WIDTH
#define RASTER_HEIGHT RASTER_UPSAMPLE * UNIVERSE_HEIGHT
typedef unsigned int UniImg[RASTER_WIDTH][RASTER_HEIGHT];