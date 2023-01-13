#include "cuda.h"
#include "common/cpu_anim.h"
#include "common/book.h"

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#define DIM 1024
#define PI 3.1415926535897932f
#define MAX_TEMP 1.0f
#define MIN_TEMP 0.0001f
#define SPEED 0.25f



__global__ void copy_const_kernel ( float *iptr, float *cptr, float delta_x) {
	// map from threadIdx/blockIdx to pixel position
	int x = threadIdx.x + blockIdx.x * blockDim.x;
	int y = threadIdx.y + blockIdx.y * blockDim.y;
	int offset = x + y * blockDim.x * gridDim.x;
	
	if(cptr[offset] != 0) iptr[offset] = cptr[offset];
}
__global__ void blend_kernel(float* outSrc, const float* inSrc, int ticks, float delta_x) {
	// map from threadIdx/blockIdx to pixel position
	int x = threadIdx.x + blockDim.x * blockIdx.x;
	int y = threadIdx.y + blockDim.y * blockIdx.y;

	int offset = x + y * blockDim.x * gridDim.x;

	int left = offset - 1;
	int right = offset + 1;
	if (x == 0) left++;
	if (x == DIM - 1) right--;

	int top = offset - DIM;
	int bottom = offset + DIM;
	if (y == 0) top += DIM;
	if (y == DIM - 1) bottom -= DIM;


	float fx = x - DIM / 2; // - delta_x;
	float fy = y - DIM / 2;

	float d = sqrtf(fx * fx + fy * fy);

	unsigned char grey = (unsigned char)(128.0f + 127.0f * cos(d / 10.0f - ticks / 7.0f) / (d / 10.0f + 1.0f));

	outSrc[offset] =  1 * (inSrc[offset] + SPEED * (inSrc[top] + inSrc[bottom] + inSrc[left] + inSrc[right] - inSrc[offset] * 4)) + grey * 0.4;

}


struct DataBlock {
	unsigned char* output_bitmap;
	float* dev_inSrc;
	float* dev_outSrc;
	float* dev_constSrc;

	CPUAnimBitmap* bitmap;
	cudaEvent_t start, stop;
	float totalTime;
	float frames;
};

void anim_gpu(DataBlock* d, int ticks) {
	cudaEventRecord(d->start, 0);

	dim3 blocks(DIM / 16, DIM / 16);
	dim3 threads(16, 16);

	CPUAnimBitmap* bitmap = d->bitmap;
	printf("b %f", bitmap->deltaX);
	for (int i = 0; i < 200; i++) {
		copy_const_kernel << <blocks, threads >> > (d->dev_inSrc, d->dev_constSrc, 1);

		blend_kernel << <blocks, threads >> > (d->dev_outSrc, d->dev_inSrc, ticks, 1000);

		swap(d->dev_inSrc, d->dev_outSrc);
	}



	float_to_color << <blocks, threads >> > (d->output_bitmap, d->dev_inSrc);

    //recalc squares here
	cudaMemcpy(bitmap->get_ptr(), d->output_bitmap, bitmap->image_size(), cudaMemcpyDeviceToHost);


	cudaEventRecord(d->stop, 0);
	cudaEventSynchronize(d->stop);

	float elapsedTime;
	cudaEventElapsedTime(&elapsedTime, d->start, d->stop);

	d->totalTime += elapsedTime;
	++d->frames;
}

void anim_exit(DataBlock* d) {
	cudaFree(d->dev_inSrc);
	cudaFree(d->dev_outSrc);
	cudaFree(d->dev_constSrc);

	cudaEventDestroy(d->start);
	cudaEventDestroy(d->stop);
}

int main() {
	DataBlock data;
	CPUAnimBitmap bitmap(DIM, DIM, &data);
	data.bitmap = &bitmap;
	data.totalTime = 0;
	data.frames = 0;

	cudaEventCreate(&data.start);
	cudaEventCreate(&data.stop);

	cudaMalloc(&data.output_bitmap, bitmap.image_size());

	cudaMalloc(&data.dev_inSrc, bitmap.image_size());
	cudaMalloc(&data.dev_outSrc, bitmap.image_size());
	cudaMalloc(&data.dev_constSrc, bitmap.image_size());

	float* temp = new float[bitmap.image_size()];

	for (int i = 0; i < DIM * DIM; i++) {
		temp[i] = 0;
		int x = i % DIM;
		int y = i / DIM;
		if ((x > 200) && (x < 700) && (y > 210) && (y < 701))
			temp[i] = MAX_TEMP;
	}

	temp[DIM * 100 + 100] = (MAX_TEMP + MIN_TEMP) / 2;
	temp[DIM * 700 + 100] = MIN_TEMP;
	temp[DIM * 300 + 300] = MIN_TEMP;
	temp[DIM * 200 + 700] = MIN_TEMP;

	for (int y = 800; y < 900; y++) {
		for (int x = 400; x < 500; x++) {
			temp[x + y * DIM] = MIN_TEMP;
		}
	}

	cudaMemcpy(data.dev_constSrc, temp, bitmap.image_size(), cudaMemcpyHostToDevice);


	for (int y = 800; y < DIM; y++) {
		for (int x = 0; x < 200; x++) {
			temp[x + y * DIM] = MAX_TEMP;
		}
	}

	cudaMemcpy(data.dev_inSrc, temp, bitmap.image_size(), cudaMemcpyHostToDevice);
	free(temp);

	bitmap.anim_and_exit((void(*)(void*, int))anim_gpu, (void(*)(void*)) anim_exit);


	return 0;
}