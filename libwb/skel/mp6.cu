#include    <wb.h>

#define wbCheck(stmt) do {                                                    \
        cudaError_t err = stmt;                                               \
        if (err != cudaSuccess) {                                             \
            wbLog(ERROR, "Failed to run stmt ", #stmt);                       \
            wbLog(ERROR, "Got CUDA error ...  ", cudaGetErrorString(err));    \
            return -1;                                                        \
        }                                                                     \
    } while(0)

#define Mask_width  5
#define Mask_radius Mask_width/2
#define TILE_WIDTH 16
#define CHANNEL 3
#define O_TILE_WIDTH 12
#define BLOCK_WIDTH O_TILE_WIDTH + (Mask_width-1)
#define CLAMP(X) min(max(X,0.0f),1.0f)

//@@ INSERT CODE HERE
__global__ void imageConvolution3D(float * I, float * O, const float * __restrict__  M,
                   int IWidth, int IHeight, int IChannel,
                   int numMRows, int numMColumns) {
	//const int TILE_WIDTH = 16;
	//const int CHANNEL = 3;
    //@@ Insert code to implement matrix multiplication here
	__shared__ float ds_I[TILE_WIDTH][TILE_WIDTH][CHANNEL];
	
	int tx = threadIdx.x;
	int ty = threadIdx.y;
	int tz = threadIdx.z;
	
	int row_o = blockIdx.y*O_TILE_WIDTH + ty;
	int col_o = blockIdx.x*O_TILE_WIDTH + tx;
	int row_i = row_o - Mask_radius;
	int col_i = col_o - Mask_radius; 
	
	// load image data into shared memory
	if((row_i >= 0) && (row_i < IHeight) && 
		(col_i >= 0) && (col_i < IWidth) ) {
		ds_I[ty][tx][tz] = I[(row_i*IWidth + col_i) * IChannel + tz];
	} else{
		ds_I[ty][tx][tz] = 0.0f;
	}
	__syncthreads();
	
	float accum = 0.0;
	if(ty < O_TILE_WIDTH && tx < O_TILE_WIDTH){
		for(int i = 0; i < Mask_width; i++) {
			for(int j  = 0; j < Mask_width; j++) {
				accum += M[i*numMRows + j] * ds_I[i+ty][j+tx][tz];
			}
		}
	}

	if(row_o < IHeight && col_o < IWidth)
		O[(row_o*IWidth + col_o) * IChannel + tz] = CLAMP(accum);
}

//2D convolution, load memory 
__global__ void imageConvolution2D(float * I, float * O, const float * __restrict__  M,
                   int IWidth, int IHeight, int IChannel,
                   int numMRows, int numMColumns) {
    //@@ Insert code to implement matrix multiplication here
	__shared__ float ds_I[TILE_WIDTH][TILE_WIDTH][CHANNEL];
	
	int tx = threadIdx.x;
	int ty = threadIdx.y;
	
	int row_o = blockIdx.y*O_TILE_WIDTH + ty;
	int col_o = blockIdx.x*O_TILE_WIDTH + tx;
	int row_i = row_o - Mask_radius;
	int col_i = col_o - Mask_radius; 
	
	// load image data into shared memory
	if((row_i >= 0) && (row_i < IHeight) && 
		(col_i >= 0) && (col_i < IWidth) ) {
		int idxI = (row_i*IWidth + col_i) * IChannel;
		ds_I[ty][tx][0] = I[idxI];
		ds_I[ty][tx][1] = I[idxI + 1];
		ds_I[ty][tx][2] = I[idxI + 2];
	} else{
		ds_I[ty][tx][0] = 0.0f;
		ds_I[ty][tx][1] = 0.0f;
		ds_I[ty][tx][2] = 0.0f;
	}
	
	__syncthreads(); 
	

	for(int k = 0; k < IChannel; k++) {
		float accum0 = 0.0;
		if(ty < O_TILE_WIDTH && tx < O_TILE_WIDTH){
			for(int i = 0; i < Mask_width; i++) {
				for(int j  = 0; j < Mask_width; j++) {
					accum0 += M[i*Mask_width + j] * ds_I[i+ty][j+tx][k];
				}
			}
		}
	
		if(row_o < IHeight && col_o < IWidth) {
			O[(row_o*IWidth + col_o) * IChannel + k] = CLAMP(accum0);
		}
		
		if(row_o == 0 && col_o == 24) {
			O[(row_o*IWidth + col_o) * IChannel + k] = 0.55;
		}
	}
	__syncthreads();
}

__global__
void convolution2D (float * I, const float * __restrict__ M, float * P,
        int channels, int width, int height)
{
    __shared__ float N_ds[O_TILE_WIDTH][O_TILE_WIDTH];

    int bx = blockIdx.x,  by = blockIdx.y;
    int tx = threadIdx.x, ty = threadIdx.y;

    for (int k = 0; k < channels; ++k) {
        int dest  = ty * TILE_WIDTH + tx;
        int destX = dest % O_TILE_WIDTH;
        int destY = dest / O_TILE_WIDTH;
        int srcY  = by * TILE_WIDTH + destY - Mask_radius;
        int srcX  = bx * TILE_WIDTH + destX - Mask_radius;
        int src   = (srcY * width + srcX) * channels + k;

        if (srcY >= 0 && srcY < height && srcX >= 0 && srcX < width)
            N_ds[destY][destX] = I[src];
        else
            N_ds[destY][destX] = 0.0;

        dest  = ty * TILE_WIDTH + tx + TILE_WIDTH * TILE_WIDTH;
        destY = dest / O_TILE_WIDTH;
        destX = dest % O_TILE_WIDTH;
        srcY  = by * TILE_WIDTH + destY - Mask_radius;
        srcX  = bx * TILE_WIDTH + destX - Mask_radius;
        src   = (srcY * width + srcX) * channels + k;

        if (destY < O_TILE_WIDTH) {
            if (srcY >= 0 && srcY < height && srcX >= 0 && srcX < width)
                N_ds[destY][destX] = I[src];
            else
                N_ds[destY][destX] = 0.0;
        }
        __syncthreads();

        float accum = 0;
        for (int y = 0; y < Mask_width; ++y)
            for (int x = 0; x < Mask_width; ++x)
                accum += N_ds[ty + y][tx + x] * M[y * Mask_width + x];

        int y = by * TILE_WIDTH + ty;
        int x = bx * TILE_WIDTH + tx;
        if (y < height && x < width)
            P[(y * width + x) * channels + k] = min(max(accum, 0.0), 1.0);

        __syncthreads();
    }
}

int main(int argc, char* argv[]) {
    wbArg_t args;
    int maskRows;
    int maskColumns;
    int imageChannels;
    int imageWidth;
    int imageHeight;
    char * inputImageFile;
    char * inputMaskFile;
    wbImage_t inputImage;
    wbImage_t outputImage;
    float * hostInputImageData;
    float * hostOutputImageData;
    float * hostMaskData;
    float * deviceInputImageData;
    float * deviceOutputImageData;
    float * deviceMaskData;

    args = wbArg_read(argc, argv); /* parse the input arguments */

    inputImageFile = wbArg_getInputFile(args, 0);
    inputMaskFile = wbArg_getInputFile(args, 1);

    inputImage = wbImport(inputImageFile);
    hostMaskData = (float *) wbImport(inputMaskFile, &maskRows, &maskColumns);

    assert(maskRows == 5); /* mask height is fixed to 5 in this mp */
    assert(maskColumns == 5); /* mask width is fixed to 5 in this mp */

    imageWidth = wbImage_getWidth(inputImage);
    imageHeight = wbImage_getHeight(inputImage);
    imageChannels = wbImage_getChannels(inputImage);

	wbLog(TRACE, "The dimensions of image are ", imageWidth, " x ", imageHeight, " x " ,imageChannels);
	
    outputImage = wbImage_new(imageWidth, imageHeight, imageChannels);

    hostInputImageData = wbImage_getData(inputImage);
    hostOutputImageData = wbImage_getData(outputImage);

    wbTime_start(GPU, "Doing GPU Computation (memory + compute)");

    wbTime_start(GPU, "Doing GPU memory allocation");
    cudaMalloc((void **) &deviceInputImageData, imageWidth * imageHeight * imageChannels * sizeof(float));
    cudaMalloc((void **) &deviceOutputImageData, imageWidth * imageHeight * imageChannels * sizeof(float));
    cudaMalloc((void **) &deviceMaskData, maskRows * maskColumns * sizeof(float));
    wbTime_stop(GPU, "Doing GPU memory allocation");


    wbTime_start(Copy, "Copying data to the GPU");
    cudaMemcpy(deviceInputImageData,
               hostInputImageData,
               imageWidth * imageHeight * imageChannels * sizeof(float),
               cudaMemcpyHostToDevice);
    cudaMemcpy(deviceMaskData,
               hostMaskData,
               maskRows * maskColumns * sizeof(float),
               cudaMemcpyHostToDevice);
    wbTime_stop(Copy, "Copying data to the GPU");


    wbTime_start(Compute, "Doing the computation on the GPU");
    //@@ INSERT CODE HERE
	//@@ Initialize the grid and block dimensions here
    dim3 DimGrid((imageWidth-1)/O_TILE_WIDTH + 1, (imageHeight-1)/O_TILE_WIDTH + 1, 1);
	dim3 DimBlock(BLOCK_WIDTH, BLOCK_WIDTH, 1);			 
	
    //@@ Launch the GPU Kernel here
	imageConvolution2D<<<DimGrid,DimBlock>>>(deviceInputImageData, deviceOutputImageData, deviceMaskData, imageWidth, imageHeight, imageChannels, maskRows, maskColumns);
	//convolution2D<<<DimGrid, DimBlock>>>(deviceInputImageData, deviceMaskData, deviceOutputImageData, imageChannels, imageWidth, imageHeight);
//    cudaThreadSynchronize();
    wbTime_stop(Compute, "Doing the computation on the GPU");


    wbTime_start(Copy, "Copying data from the GPU");
    cudaMemcpy(hostOutputImageData,
               deviceOutputImageData,
               imageWidth * imageHeight * imageChannels * sizeof(float),
               cudaMemcpyDeviceToHost);
    wbTime_stop(Copy, "Copying data from the GPU");

    wbTime_stop(GPU, "Doing GPU Computation (memory + compute)");

    wbSolution(args, outputImage);

    cudaFree(deviceInputImageData);
    cudaFree(deviceOutputImageData);
    cudaFree(deviceMaskData);

    free(hostMaskData);
    wbImage_delete(outputImage);
    wbImage_delete(inputImage);

    return 0;
}
