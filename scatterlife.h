
#define UNIVERSE_WIDTH 256
#define UNIVERSE_HEIGHT 256

typedef struct {
  unsigned int bound[6];
  unsigned int unbound[6];
} Cell;

struct RGB
{
  float R;
  float G;
  float B;
};


typedef Cell Universe[UNIVERSE_WIDTH][UNIVERSE_HEIGHT];

#define RASTER_UPSAMPLE 1
#define RASTER_WIDTH (RASTER_UPSAMPLE * UNIVERSE_WIDTH)
#define RASTER_HEIGHT (RASTER_UPSAMPLE * UNIVERSE_HEIGHT)
typedef RGB UniImg[RASTER_WIDTH][RASTER_HEIGHT];

#define INITIAL_PARTICLE_COUNT (UNIVERSE_WIDTH*UNIVERSE_HEIGHT)