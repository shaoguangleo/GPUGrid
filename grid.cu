#include <iostream>
#include "math.h"
#include "stdlib.h"

#include "grid_gpu.cuh"
#include "Defines.h"
#include "cuda.h"

//With managed memory, grid.cpp must be compiled as CUDA
//in which case float2 and double2 are predefined.
//typedef struct {float x,y;} float2;
//typedef struct {double x,y;} double2;

#define single 77
#if PRECISION==single
#define PRECISION float
#endif

#ifndef PRECISION
#define PRECISION double
#endif
#define PASTER(x) x ## 2
#define EVALUATOR(x) PASTER(x)
#define PRECISION2 EVALUATOR(PRECISION)


void init_gcf(PRECISION2 *gcf, size_t size) {

  for (size_t sub_x=0; sub_x<GCF_GRID; sub_x++ )
   for (size_t sub_y=0; sub_y<GCF_GRID; sub_y++ )
    for(size_t x=0; x<size; x++)
     for(size_t y=0; y<size; y++) {
       //Some nonsense GCF
       PRECISION tmp = sin(6.28*x/size/GCF_GRID)*exp(-(1.0*x*x+1.0*y*y*sub_y)/size/size/2);
       gcf[size*size*(sub_x+sub_y*GCF_GRID)+x+y*size].x = tmp*sin(1.0*x*sub_x/(y+1))+0.4;
       gcf[size*size*(sub_x+sub_y*GCF_GRID)+x+y*size].y = tmp*cos(1.0*x*sub_x/(y+1))-0.2;
       //std::cout << tmp << gcf[x+y*size].x << gcf[x+y*size].y << std::endl;
     }

}

void gridCPU(PRECISION2* out, PRECISION2 *in, PRECISION2 *in_vals, size_t npts, size_t img_dim, PRECISION2 *gcf, size_t gcf_dim) {
//degrid on the CPU
//  out (out) - the output image
//  in  (in)  - the input locations
//  in_vals (in) - input values
//  npts (in) - number of locations
//  img_dim (in) - dimension of the image
//  gcf (in) - the gridding convolution function
//  gcf_dim (in) - dimension of the GCF

   //Zero the output
   for (size_t n=0;n<IMG_SIZE*IMG_SIZE; n++) out[n].x = out[n].y = 0.0;
   //offset gcf to point to the middle for cleaner code later
   gcf += GCF_DIM*(GCF_DIM-1)/2-1;
//#pragma acc parallel loop copyout(out[0:NPOINTS]) copyin(in[0:NPOINTS],gcf[0:GCF_GRID*GCF_GRID*GCF_DIM*GCF_DIM],img[IMG_SIZE*IMG_SIZE]) gang
//#pragma omp parallel for
   for(size_t n=0; n<NPOINTS; n++) {
      //std::cout << "in = " << in[n].x << ", " << in[n].y << std::endl;
      int sub_x = floorf(GCF_GRID*(in[n].x-floorf(in[n].x)));
      int sub_y = floorf(GCF_GRID*(in[n].y-floorf(in[n].y)));
      //std::cout << "sub = "  << sub_x << ", " << sub_y << std::endl;
      int main_x = floor(in[n].x); 
      int main_y = floor(in[n].y); 
      //std::cout << "main = " << main_x << ", " << main_y << std::endl;
//      #pragma acc parallel loop collapse(2) reduction(+:sum_r,sum_i) vector
//#pragma omp parallel for collapse(2) reduction(+:sum_r, sum_i)
      for (int a=GCF_DIM/2; a>-GCF_DIM/2 ;a--)
      for (int b=GCF_DIM/2; b>-GCF_DIM/2 ;b--) {
         PRECISION r2 = gcf[GCF_DIM*GCF_DIM*(GCF_GRID*sub_y+sub_x) + 
                        GCF_DIM*b+a].x;
         PRECISION i2 = gcf[GCF_DIM*GCF_DIM*(GCF_GRID*sub_y+sub_x) + 
                        GCF_DIM*b+a].y;
         PRECISION r1, i1;
         r1 = in_vals[n].x;
         i1 = in_vals[n].y;
         if (main_x+a < 0 || main_y+b < 0 || 
             main_x+a >= IMG_SIZE  || main_y+b >= IMG_SIZE) {
         } else {
#ifdef DEBUG1
               out[main_x+a+IMG_SIZE*(main_y+b)].x += 1;
               out[main_x+a+IMG_SIZE*(main_y+b)].y += n;
#else
               out[main_x+a+IMG_SIZE*(main_y+b)].x += r1*r2-i1*i2; 
               out[main_x+a+IMG_SIZE*(main_y+b)].y += r1*i2+r2*i1;
#endif
         }
      }
      //std::cout << "val = " << out[n].r << "+ i" << out[n].i << std::endl;
   } 
   gcf -= GCF_DIM*(GCF_DIM-1)/2-1;
}
void gridCPU_pz(PRECISION2* out, PRECISION2 *in, PRECISION2 *in_vals, size_t npts, size_t img_dim, PRECISION2 *gcf, size_t gcf_dim) {
//degrid on the CPU
//  out (out) - the output image
//  in  (in)  - the input locations
//  in_vals (in) - input values
//  npts (in) - number of locations
//  img_dim (in) - dimension of the image
//  gcf (in) - the gridding convolution function
//  gcf_dim (in) - dimension of the GCF

   //Zero the output
   //offset gcf to point to the middle for cleaner code later
   gcf += GCF_DIM*(GCF_DIM-1)/2-1;
//#pragma acc parallel loop copyout(out[0:NPOINTS]) copyin(in[0:NPOINTS],gcf[0:GCF_GRID*GCF_GRID*GCF_DIM*GCF_DIM],img[IMG_SIZE*IMG_SIZE]) gang
//#pragma omp parallel for
   for(size_t n=0; n<NPOINTS; n++) {
      //std::cout << "in = " << in[n].x << ", " << in[n].y << std::endl;
      int sub_x = floorf(GCF_GRID*(in[n].x-floorf(in[n].x)));
      int sub_y = floorf(GCF_GRID*(in[n].y-floorf(in[n].y)));
      //std::cout << "sub = "  << sub_x << ", " << sub_y << std::endl;
      int main_x = floor(in[n].x); 
      int main_y = floor(in[n].y); 
      //std::cout << "main = " << main_x << ", " << main_y << std::endl;
//      #pragma acc parallel loop collapse(2) reduction(+:sum_r,sum_i) vector
//#pragma omp parallel for collapse(2) reduction(+:sum_r, sum_i)
      for (int a=GCF_DIM/2; a>-GCF_DIM/2 ;a--)
      for (int b=GCF_DIM/2; b>-GCF_DIM/2 ;b--) {
         PRECISION r2 = gcf[GCF_DIM*GCF_DIM*(GCF_GRID*sub_y+sub_x) + 
                        GCF_DIM*b+a].x;
         PRECISION i2 = gcf[GCF_DIM*GCF_DIM*(GCF_GRID*sub_y+sub_x) + 
                        GCF_DIM*b+a].y;
         PRECISION r1, i1;
         if (main_x+a < 0 || main_y+b < 0 || 
             main_x+a >= IMG_SIZE  || main_y+b >= IMG_SIZE) {
         } else {
            for (int p=0;p< POLARIZATIONS;p++) {
               r1 = in_vals[POLARIZATIONS*n+p].x;
               i1 = in_vals[POLARIZATIONS*n+p].y;
#ifdef DEBUG1
               out[main_x+a+IMG_SIZE*(main_y+b)+p*IMG_SIZE*IMG_SIZE].x += 1;
               out[main_x+a+IMG_SIZE*(main_y+b)+p*IMG_SIZE*IMG_SIZE].y += n;
#else
               out[main_x+a+IMG_SIZE*(main_y+b)+p*IMG_SIZE*IMG_SIZE].x += r1*r2-i1*i2; 
               out[main_x+a+IMG_SIZE*(main_y+b)+p*IMG_SIZE*IMG_SIZE].y += r1*i2+r2*i1;
#endif
            }
         }
      }
      //std::cout << "val = " << out[n].r << "+ i" << out[n].i << std::endl;
   } 
   gcf -= GCF_DIM*(GCF_DIM-1)/2-1;
}
template <class T,class Thalf>
int w_comp_main(const void* A, const void* B) {
   Thalf quota, rema, quotb, remb;
   rema = modf((*((T*)A)).x, &quota);
   remb = modf((*((T*)B)).x, &quotb);
   if (quota > quotb) return 1;
   if (quota < quotb) return -1;
   else {
     rema = modf((*((T*)A)).y, &quota);
     remb = modf((*((T*)B)).y, &quotb);
     if (quota > quotb) return 1;
     if (quota < quotb) return -1;
     else return 0;
   }
   return 0;
}
template <class T,class Thalf>
int w_comp_sub(const void* A, const void* B) {
   Thalf quota, rema, quotb, remb;
   rema = modf((*((T*)A)).x, &quota);
   remb = modf((*((T*)B)).x, &quotb);
   int sub_xa = (int) (GCF_GRID*rema);
   int sub_xb = (int) (GCF_GRID*remb);
   rema = modf((*((T*)A)).y, &quota);
   remb = modf((*((T*)B)).y, &quotb);
   int suba = (int) (GCF_GRID*rema) + GCF_GRID*sub_xa;
   int subb = (int) (GCF_GRID*remb) + GCF_GRID*sub_xb;
   if (suba > subb) return 1;
   if (suba < subb) return -1;
   return 0;
}
template <class T,class Thalf>
int w_comp_full(const void* A, const void* B) {
   int result = w_comp_sub<T,Thalf>(A,B);
   if (0==result) return w_comp_main<T,Thalf>(A,B);
   else return result;
}
#if 0
struct comp_grid {
   int blockgrid, blocksize;
   public:
   comp_grid(int img_dim, int gcf_dim) {
      blocksize = gcf_dim/2;
      blockgrid = img_dim/blocksize;
   }
   int __cdecl operator () (const void* A, const void* B) const {
      int gridxa = (*(int2*)A).x/GCF_GRID;
      int gridxb = (*(int2*)B).x/GCF_GRID;
      int gridya = (*(int2*)A).y/GCF_GRID;
      int gridyb = (*(int2*)B).y/GCF_GRID;
      if (gridya > gridyb) return 1;
      if (gridya < gridyb) return -1;
      if (gridxa > gridxb) return 1;
      if (gridxa < gridxb) return  -1;
      int suba = GCF_GRID*((*(int2*)A).x%GCF_GRID) + (*(int2*)A).y%GCF_GRID;
      int subb = GCF_GRID*((*(int2*)B).x%GCF_GRID) + (*(int2*)B).y%GCF_GRID;
      if (suba > subb) return 1;
      if (suba < subb) return -1;
      return  0;
   }
};
#else
template <class T, class Thalf>
int comp_grid (const void* A, const void* B) {
      int blocksize = GCF_DIM/2;
      int mainxa = floorf((*(T*)A).x);
      int mainxb = floorf((*(T*)B).x);
      int mainya = floorf((*(T*)A).y);
      int mainyb = floorf((*(T*)B).y);
      int gridxa = mainxa/blocksize;
      int gridxb = mainxb/blocksize;
      int gridya = mainya/blocksize;
      int gridyb = mainyb/blocksize;
      if (gridya*(IMG_SIZE+blocksize-1)/blocksize+gridxa > 
          gridyb*(IMG_SIZE+blocksize-1)/blocksize+gridxb) return 1;
      if (gridya*(IMG_SIZE+blocksize-1)/blocksize+gridxa < 
          gridyb*(IMG_SIZE+blocksize-1)/blocksize+gridxb) return -1;
      Thalf suba = GCF_GRID*((*(T*)A).x-mainxa) + (*(T*)A).y-mainya;
      Thalf subb = GCF_GRID*((*(T*)B).x-mainxb) + (*(T*)B).y-mainyb;
      if (suba > subb) return 1;
      if (suba < subb) return -1;
      return  0;
}
#endif


int main(void) {

#ifdef __MANAGED
   PRECISION2* out, *in, *in_vals, *gcf;
   cudaMallocManaged(&out, sizeof(PRECISION2)*(IMG_SIZE*IMG_SIZE+2*IMG_SIZE*GCF_DIM+2*GCF_DIM)*POLARIZATIONS);
   cudaMallocManaged(&in, sizeof(PRECISION2)*NPOINTS);
   cudaMallocManaged(&in_vals, sizeof(PRECISION2)*NPOINTS*POLARIZATIONS);
   cudaMallocManaged(&gcf, sizeof(PRECISION2)*64*GCF_DIM*GCF_DIM);
#else
   PRECISION2* out = (PRECISION2*) malloc(sizeof(PRECISION2)*(IMG_SIZE*IMG_SIZE+2*IMG_SIZE*GCF_DIM+2*GCF_DIM)*POLARIZATIONS);
   PRECISION2* in = (PRECISION2*) malloc(sizeof(PRECISION2)*NPOINTS);
   PRECISION2* in_vals = (PRECISION2*) malloc(sizeof(PRECISION2)*NPOINTS*POLARIZATIONS);

   PRECISION2 *gcf = (PRECISION2*) malloc(64*GCF_DIM*GCF_DIM*sizeof(PRECISION2));
#endif

   init_gcf(gcf, GCF_DIM);
#ifdef __FILE_INPUT
   FILE *uvw_f = fopen("UVW_in.dat", "r");
   int junka,junkb,junkc;
   float fjunka, fjunkb, fjunkc;
   float max_x, min_x, max_y, min_y;
   max_x = max_y = INT_MIN;
   min_x = min_y = INT_MAX;
   for(size_t n=0; n<NPOINTS; n++) {
      fscanf(uvw_f, "%d,%d,%d: %f, %f, %f\n", &junka, &junkb, &junkc, &fjunka, &fjunkb, &fjunkc);
      in[n].x = fjunka*IMG_SIZE/2048.;
      in[n].y = fjunkb*IMG_SIZE/2048.;
      min_x = in[n].x < min_x ? in[n].x : min_x;
      max_x = in[n].x > max_x ? in[n].x : max_x;
      min_y = in[n].y < min_y ? in[n].y : min_y;
      max_y = in[n].y > max_y ? in[n].y : max_y;
      for (int p=0;p<POLARIZATIONS;p++) {
         in_vals[POLARIZATIONS*n+p].x = ((float)rand())/RAND_MAX;
         in_vals[POLARIZATIONS*n+p].y = ((float)rand())/RAND_MAX;
      }
   }
   printf("%f -- %f, %f -- %f\n", min_x, max_x, min_y, max_y);
   fclose(uvw_f);
#else
   srand(2541617);
   for(size_t n=0; n<NPOINTS; n++) {
      in[n].x = ((float)rand())/RAND_MAX*IMG_SIZE;
      in[n].y = ((float)rand())/RAND_MAX*IMG_SIZE;
      for (int p=0;p<POLARIZATIONS;p++) {
         in_vals[POLARIZATIONS*n+p].x = ((float)rand())/RAND_MAX;
         in_vals[POLARIZATIONS*n+p].y = ((float)rand())/RAND_MAX;
      }
   }
#endif
   //Zero the data in the offset areas
   //for (int x=-IMG_SIZE*GCF_DIM-GCF_DIM;x<0;x++) {
   //   out[x].x = 0.0; out[x].y = 0.0;
  // }
   for (int x=0;x<IMG_SIZE*GCF_DIM*POLARIZATIONS+GCF_DIM*POLARIZATIONS;x++) {
      out[x].x=0.0;
      out[x].y=0.0;
      out[x+(IMG_SIZE*IMG_SIZE+IMG_SIZE*GCF_DIM+GCF_DIM)*POLARIZATIONS].x = 0.0;
      out[x+(IMG_SIZE*IMG_SIZE+IMG_SIZE*GCF_DIM+GCF_DIM)*POLARIZATIONS].y = 0.0;
   }


#ifdef __GATHER
   std::qsort(in, NPOINTS, sizeof(PRECISION2), comp_grid<PRECISION2,PRECISION>);
#else
#ifdef __MOVING_WINDOW
   std::qsort(in, NPOINTS, sizeof(PRECISION2), w_comp_main<PRECISION2,PRECISION>);
#else
   std::qsort(in, NPOINTS, sizeof(PRECISION2), w_comp_sub<PRECISION2,PRECISION>);
#endif
#endif
   
   //auto tmp = in[0];
   //in[0] = in[204];
   //in[204]=tmp;
   std::cout << "Computing on GPU..." << std::endl;
   gridGPU(out,in,in_vals,NPOINTS,IMG_SIZE,gcf,GCF_DIM);
#ifdef __CPU_CHECK
   std::cout << "Computing on CPU..." << std::endl;
   PRECISION2 *out_cpu=(PRECISION2*)malloc(sizeof(PRECISION2)*(IMG_SIZE*IMG_SIZE+2*IMG_SIZE*GCF_DIM+2*GCF_DIM)*POLARIZATIONS);
   memset(out_cpu, 0, sizeof(PRECISION2)*(IMG_SIZE*IMG_SIZE+2*IMG_SIZE*GCF_DIM+2*GCF_DIM)*POLARIZATIONS);
   
   gridCPU_pz(out_cpu+IMG_SIZE*GCF_DIM+GCF_DIM,in,in_vals,NPOINTS,IMG_SIZE,gcf,GCF_DIM);
   //gridCPU(out+IMG_SIZE*GCF_DIM+GCF_DIM,in,in_vals,NPOINTS,IMG_SIZE,gcf,GCF_DIM);
#endif


#ifdef __CPU_CHECK
   std::cout << "Checking results against CPU:" << std::endl;
   for (size_t yy = 0; yy < IMG_SIZE; yy++) {
   for (size_t xx = 0; xx < IMG_SIZE; xx++) {
     int n = GCF_DIM+IMG_SIZE*GCF_DIM+yy*IMG_SIZE+xx;
     for (int p = 0; p < IMG_SIZE*IMG_SIZE*POLARIZATIONS; p+=IMG_SIZE*IMG_SIZE) {
        if (fabs(out[n+p].x-out_cpu[n+p].x) > 0.0000001 ||
            fabs(out[n+p].y-out_cpu[n+p].y) > 0.0000001 )
           std::cout << xx << ", " << yy << "[" << p/IMG_SIZE/IMG_SIZE << "] : " 
                     << "(" << n+p-(GCF_DIM+IMG_SIZE*GCF_DIM) << ") "
                     << out[n+p].x << ", " << out[n+p].y 
                     << " vs. " << out_cpu[n+p].x << ", " << out_cpu[n+p].y 
                     << std::endl;
     }
   }
   }
   //std::cout << "free out_cpu" << std::endl;
   //free(out_cpu);out_cpu=NULL;
#endif
#ifdef __MANAGED
   cudaFree(out);out=NULL;
   cudaFree(in);in=NULL;
   cudaFree(in_vals);in_vals=NULL;
   cudaFree(gcf);gcf=NULL;
#else
   free(out);out=NULL;
   free(in);in=NULL;
   free(in_vals);in_vals=NULL;
   free(gcf);gcf=NULL;
#endif
}
