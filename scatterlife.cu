#include <stdio.h>
#include <stdlib.h>
#include <windows.h>
#include <builtin_types.h>

#include <GL/glew.h>
#include <GLFW/glfw3.h>

#include "scatterlife.h" 


// CUDA runtime
//#include <cooperative_groups.h>
//using namespace cooperative_groups;


GLuint rasterTexture;

GLFWwindow* window;


void framebuffer_size_callback(GLFWwindow* window, int width, int height)
{
    glViewport(0, 0, width, height);
}









//=========================================
// BEGIN CUDA KERNELS
//=========================================






__device__ Universe univ = {};
__device__ Universe univ2 = {};


__device__ UniImg raster = {};

__device__ volatile unsigned int gTime = 1; 

//__device__ volatile unsigned int maxParticleCount = 0;


Universe host_univ = {};
UniImg host_raster = {};





// hexagonal particle storage
// 0 N
// 1 NE
// 2 SE
// 3 S
// 4 SW
// 5 NW

__global__ void runAutomata(bool direction){

  Universe* origin;
  Universe* target;
  if (direction){
    origin = &univ;
    target = &univ2;
  }else{
    origin = &univ2;
    target = &univ;
  }

  unsigned int x = blockIdx.x;
  unsigned int y = blockIdx.y;

  unsigned int seed = gTime; //+ x + y + x*y + y*x*x+ y*y*x;

  unsigned int xm1 = x >= 1 ? x-1 : (UNIVERSE_WIDTH - 1);
  unsigned int xp1 = x < (UNIVERSE_WIDTH - 1) ? x+1 : 0;

  unsigned int ym1 = y >= 1 ? y-1 : (UNIVERSE_HEIGHT - 1);
  unsigned int yp1 = y < (UNIVERSE_HEIGHT - 1) ? y+1 : 0;


  unsigned int incoming[6] = {
    (*origin)   [x] [ym1]  .unbound[0],   
    (*origin) [xp1] [ym1]  .unbound[1],
    (*origin) [xp1]   [y]  .unbound[2],   
    (*origin)   [x] [yp1]  .unbound[3],   
    (*origin) [xm1] [yp1]  .unbound[4], 
    (*origin) [xm1]   [y]  .unbound[5]   
  };

  //this_grid().sync();

  unsigned int triforce_a = min(min(incoming[0], incoming[2]), incoming[4]);
  unsigned int triforce_b = min(min(incoming[1], incoming[3]), incoming[5]);

  unsigned int pair_a = min(incoming[0], incoming[3]);
  unsigned int pair_b = min(incoming[1], incoming[4]);
  unsigned int pair_c = min(incoming[2], incoming[5]);
  
  unsigned int pairTriforceOverlap = min( 
    max(max(pair_a, pair_b), pair_c),
    max(triforce_a, triforce_b)
  );

  unsigned int pairsKept = seed % (pairTriforceOverlap + 1);
  unsigned int triforcesKept = pairTriforceOverlap - pairsKept;

  pair_a -= min(pair_a, triforcesKept);
  pair_b -= min(pair_b, triforcesKept);
  pair_c -= min(pair_c, triforcesKept);

  unsigned int final_pairs = pair_a + pair_b + pair_c;

  triforce_a -= min(triforce_a, pairsKept);
  triforce_b -= min(triforce_b, pairsKept);


  unsigned int final_triforces = triforce_a + triforce_b;
  

  

  unsigned int triforce_cut = seed % (final_triforces + 1);

  unsigned int final_triforce_a = triforce_cut;
  unsigned int final_triforce_b = final_triforces - triforce_cut;

  // ordered pairing function
  unsigned int z = seed % (
     (final_pairs + 1)*(final_pairs + 2)/2
  );

  unsigned int w = (sqrtf(8*z + 1) - 1) / 2;
  unsigned int pair_cut_1 = z - w*(w+1)/2;
  unsigned int pair_cut_2 = w;

  unsigned int final_pair_a = pair_cut_1;
  unsigned int final_pair_b = pair_cut_2 - pair_cut_1;
  unsigned int final_pair_c = final_pairs - pair_cut_2;



  unsigned int scattering[6] = {
    final_triforce_a + final_pair_a,
    final_triforce_b + final_pair_b,
    final_triforce_a + final_pair_c,
    final_triforce_b + final_pair_a,
    final_triforce_a + final_pair_b,
    final_triforce_b + final_pair_c
  };




  

  
  (*target)[x][y] = {
    scattering[0],
    scattering[1],
    scattering[2],
    scattering[3],
    scattering[4],
    scattering[5],
    (*origin)[x][y].bound[0] + incoming[0] - triforce_a - pair_a,
    (*origin)[x][y].bound[1] + incoming[1] - triforce_b - pair_b,
    (*origin)[x][y].bound[2] + incoming[2] - triforce_a - pair_c,
    (*origin)[x][y].bound[3] + incoming[3] - triforce_b - pair_a,
    (*origin)[x][y].bound[4] + incoming[4] - triforce_a - pair_b,
    (*origin)[x][y].bound[5] + incoming[5] - triforce_b - pair_c,
  };

  if (blockIdx.x == 0){
    gTime = (48271 * gTime) % (2147483647);
  }
}

__global__ void rasterizeAutomata(){
  unsigned int x = blockIdx.x;
  unsigned int y = blockIdx.y;

  // if (blockIdx.x == 0){
  //   maxParticleCount = 0;
  // }

  // unsigned int pc = (
  //     univ[x][y].bound[0] + univ[x][y].unbound[0]
  //   + univ[x][y].bound[1] + univ[x][y].unbound[1]
  //   + univ[x][y].bound[2] + univ[x][y].unbound[2]
  //   + univ[x][y].bound[3] + univ[x][y].unbound[3]
  //   + univ[x][y].bound[4] + univ[x][y].unbound[4]
  //   + univ[x][y].bound[5] + univ[x][y].unbound[5]
  // );

  //atomicMax((unsigned int*) &maxParticleCount, pc);

  //this_grid().sync();

  //AAGGBBRR
  raster[x][y] = 
      univ[x][y].bound[0] || univ[x][y].unbound[0]
    || univ[x][y].bound[1] || univ[x][y].unbound[1]
    || univ[x][y].bound[2] || univ[x][y].unbound[2]
    || univ[x][y].bound[3] || univ[x][y].unbound[3]
    || univ[x][y].bound[4] || univ[x][y].unbound[4]
    || univ[x][y].bound[5] || univ[x][y].unbound[5] ? 0xFF000000 : 0xFFFFFFFF;

  //(unsigned int)(16777215.0 * powf(pc / maxParticleCount, 0.2)) | 0xFF000000;
}



//=========================================
// END CUDA KERNELS
//=========================================








#define gpuErrchk(ans) { gpuAssert((ans), __FILE__, __LINE__); }
inline void gpuAssert(cudaError_t code, const char *file, int line, bool abort=true)
{
   if (code != cudaSuccess) 
   {
      fprintf(stderr,"GPU Error: %s %s %d\n", cudaGetErrorString(code), file, line);
      if (abort) exit(code);
   }
}




void dump_univ(){
  for (int i = 0; i < UNIVERSE_WIDTH; ++i){
    for (int z = 0; z < UNIVERSE_HEIGHT; ++z){
      printf("%3d", host_raster[i][z]);
    }
    printf("\n");
  }
}


void initOpenGL(){

  glfwInit();

  const GLFWvidmode* mode = glfwGetVideoMode(glfwGetPrimaryMonitor());

  // glfwWindowHint(GLFW_RED_BITS, mode->redBits);
  // glfwWindowHint(GLFW_GREEN_BITS, mode->greenBits);
  // glfwWindowHint(GLFW_BLUE_BITS, mode->blueBits);
  // glfwWindowHint(GLFW_REFRESH_RATE, mode->refreshRate);

  window = glfwCreateWindow(UNIVERSE_WIDTH/2, UNIVERSE_HEIGHT/2, "ScatterLife", NULL, NULL);
  //window = glfwCreateWindow(mode->width, mode->height, "ScatterLife", NULL, NULL);

  glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);

  glfwMakeContextCurrent(window);

  glewInit();

  // setup raster to texture modes
  glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
  glGenTextures(1, &rasterTexture);   // generate a texture handler really reccomanded (mandatory in openGL 3.0)
  glBindTexture(GL_TEXTURE_2D, rasterTexture); // tell openGL that we are using the texture 

  glEnable(GL_TEXTURE_2D);

  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
  // glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);

  // glTexParameteri(GL_TEXTURE_2D, GL_GENERATE_MIPMAP, GL_TRUE);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, 
                 GL_NEAREST);
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, 
                 GL_NEAREST);
  GLfloat fLargest;
  glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY, &fLargest);
  glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_MAX_ANISOTROPY, fLargest);

  glMatrixMode(GL_PROJECTION);

  GLdouble matrix[16] = {
    sqrt(3.0), 0, 0, 0,
    sqrt(3.0)/2.0, 3.0/2.0, 0, 0,
    0, 0, 1, 0,
    0, 0, 0, 1
  };
  glLoadMatrixd(matrix);
  //glOrtho(0.0f, UNIVERSE_WIDTH, UNIVERSE_HEIGHT, 0.0f, 0.0f, 1.0f);
  //glEnable(GL_BLEND);
  //glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
}


DWORD WINAPI render( LPVOID lpParam ) {
  cudaDeviceProp prop;
  cudaGetDeviceProperties(&prop, 0);
  printf("  Device name: %s\n", prop.name);

  cudaSetDevice(0);
  initOpenGL();

  float scale = 0.7f;


  /* Loop until the user closes the window */
  while (!glfwWindowShouldClose(window))
  {
      // rasterize
      rasterizeAutomata<<<dim3(UNIVERSE_WIDTH, UNIVERSE_HEIGHT, 1), dim3(1,1,1),0,cudaStreamPerThread>>>();

      // copy raster back to host
      cudaMemcpyFromSymbolAsync(host_raster, raster, sizeof(UniImg), 0, cudaMemcpyDeviceToHost, cudaStreamPerThread);

      cudaStreamSynchronize(cudaStreamPerThread);

      //glClear(GL_COLOR_BUFFER_BIT);
      
      glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, RASTER_WIDTH, RASTER_HEIGHT, 0, GL_RGBA, GL_UNSIGNED_BYTE, host_raster);
      //glGenerateTextureMipmap(rasterTexture);

      glBegin(GL_TRIANGLE_STRIP);

      glTexCoord2f(1.0f, 1.0f); glVertex2f(-scale, -scale);
      glTexCoord2f(1.0f, 0.0f); glVertex2f(-scale, scale);
      glTexCoord2f(0.0f, 1.0f); glVertex2f(scale, -scale);
      glTexCoord2f(0.0f, 0.0f); glVertex2f(scale, scale);

      glEnd();

      glfwSwapBuffers(window);

      glfwPollEvents();
  }

  exit(0);
}


int main(int argc, char **argv)
{
  cudaDeviceProp prop;
  cudaGetDeviceProperties(&prop, 0);
  printf("  Device name: %s\n", prop.name);

  cudaSetDevice(0);
  CreateThread(NULL, 0, render, NULL, 0, NULL);

  //initialize INITIAL_PARTICLE_COUNT heading to center cell from every neighbor
  host_univ[UNIVERSE_WIDTH/2][UNIVERSE_HEIGHT/2-1].unbound[0] = INITIAL_PARTICLE_COUNT;
  host_univ[UNIVERSE_WIDTH/2+1][UNIVERSE_HEIGHT/2-1].unbound[1] = INITIAL_PARTICLE_COUNT;
  host_univ[UNIVERSE_WIDTH/2+1][UNIVERSE_HEIGHT/2].unbound[2] = INITIAL_PARTICLE_COUNT;
  host_univ[UNIVERSE_WIDTH/2][UNIVERSE_HEIGHT/2+1].unbound[3] = INITIAL_PARTICLE_COUNT;
  host_univ[UNIVERSE_WIDTH/2-1][UNIVERSE_HEIGHT/2+1].unbound[4] = INITIAL_PARTICLE_COUNT;
  host_univ[UNIVERSE_WIDTH/2-1][UNIVERSE_HEIGHT/2].unbound[5] = INITIAL_PARTICLE_COUNT;

  cudaMemcpyToSymbol(univ, host_univ, sizeof(Universe), 0, cudaMemcpyHostToDevice);

  
  for (;;){
    // for (int i = 1; i--;){
      runAutomata<<<dim3(UNIVERSE_WIDTH, UNIVERSE_HEIGHT, 1), dim3(1,1,1),0,cudaStreamPerThread >>>(true);
      runAutomata<<<dim3(UNIVERSE_WIDTH, UNIVERSE_HEIGHT, 1), dim3(1,1,1),0,cudaStreamPerThread >>>(false);
    // }
    cudaStreamSynchronize(cudaStreamPerThread);
  }
}