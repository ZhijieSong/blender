/*
 * Copyright 2011-2017 Blender Foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* CUDA kernel entry points */

#ifdef __CUDA_ARCH__

#include "util_cuda_capabilities.h"

#include "../../filter_compat_cuda.h"

#include "../../filter_kernel.h"

/* kernels */

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_divide_shadow(int sample,
                                 TilesInfo *tiles,
                                 float *unfilteredA,
                                 float *unfilteredB,
                                 float *sampleVariance,
                                 float *sampleVarianceV,
                                 float *bufferVariance,
                                 int4 prefilter_rect,
                                 int buffer_pass_stride,
                                 int buffer_denoising_offset,
                                 bool use_gradients,
                                 bool use_split_variance)
{
	int x = prefilter_rect.x + blockDim.x*blockIdx.x + threadIdx.x;
	int y = prefilter_rect.y + blockDim.y*blockIdx.y + threadIdx.y;
	if(x < prefilter_rect.z && y < prefilter_rect.w) {
		kernel_filter_divide_shadow(sample,
		                            tiles,
		                            x, y,
		                            unfilteredA,
		                            unfilteredB,
		                            sampleVariance,
		                            sampleVarianceV,
		                            bufferVariance,
		                            prefilter_rect,
		                            buffer_pass_stride,
		                            buffer_denoising_offset,
		                            use_gradients,
		                            use_split_variance);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_get_feature(int sample,
                               TilesInfo *tiles,
                               int m_offset,
                               int v_offset,
                               float *mean,
                               float *variance,
                               int4 prefilter_rect,
                               int buffer_pass_stride,
                               int buffer_denoising_offset,
                               bool use_cross_denoising,
                               bool use_split_variance)
{
	int x = prefilter_rect.x + blockDim.x*blockIdx.x + threadIdx.x;
	int y = prefilter_rect.y + blockDim.y*blockIdx.y + threadIdx.y;
	if(x < prefilter_rect.z && y < prefilter_rect.w) {
		kernel_filter_get_feature(sample,
		                          tiles,
		                          m_offset, v_offset,
		                          x, y,
		                          mean, variance,
		                          prefilter_rect,
		                          buffer_pass_stride,
		                          buffer_denoising_offset,
		                          use_cross_denoising,
		                          use_split_variance);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_combine_halves(float *mean, float *variance, float *a, float *b, int4 prefilter_rect, int r)
{
	int x = prefilter_rect.x + blockDim.x*blockIdx.x + threadIdx.x;
	int y = prefilter_rect.y + blockDim.y*blockIdx.y + threadIdx.y;
	if(x < prefilter_rect.z && y < prefilter_rect.w) {
		kernel_filter_combine_halves(x, y, mean, variance, a, b, prefilter_rect, r);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_construct_transform(int sample, float const* __restrict__ buffer,
                                       float *transform, int *rank,
                                       int4 filter_area, int4 rect,
                                       int half_window, float pca_threshold)
{
	int x = blockDim.x*blockIdx.x + threadIdx.x;
	int y = blockDim.y*blockIdx.y + threadIdx.y;
	if(x < filter_area.z && y < filter_area.w) {
		int *l_rank = rank + y*filter_area.z + x;
		float *l_transform = transform + y*filter_area.z + x;
		kernel_filter_construct_transform(sample, buffer,
		                                  x + filter_area.x, y + filter_area.y,
		                                  rect, l_transform, l_rank,
		                                  half_window, pca_threshold,
		                                  filter_area.z*filter_area.w,
		                                  threadIdx.y*blockDim.x + threadIdx.x);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_divide_combined(float *buffers, int sample,
                                   int offset, int stride,
                                   int4 filter_area, int pass_stride,
                                   int no_denoising_offset)
{
	int x = blockDim.x*blockIdx.x + threadIdx.x;
	int y = blockDim.y*blockIdx.y + threadIdx.y;
	if(x < filter_area.z && y < filter_area.w) {
		kernel_filter_divide_combined(x + filter_area.x, y + filter_area.y, sample, buffers, offset, stride, pass_stride, no_denoising_offset);
	}
}


extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_nlm_calc_difference(int dx, int dy,
                                       float ccl_readonly_ptr weightImage,
                                       float ccl_readonly_ptr varianceImage,
                                       float *differenceImage,
                                       int4 rect, int w,
                                       int channel_offset,
                                       float a, float k_2) {
	int x = blockDim.x*blockIdx.x + threadIdx.x + rect.x;
	int y = blockDim.y*blockIdx.y + threadIdx.y + rect.y;
	if(x < rect.z && y < rect.w) {
		kernel_filter_nlm_calc_difference(x, y, dx, dy, weightImage, varianceImage, differenceImage, rect, w, channel_offset, a, k_2);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_nlm_blur(float ccl_readonly_ptr differenceImage, float *outImage, int4 rect, int w, int f) {
	int x = blockDim.x*blockIdx.x + threadIdx.x + rect.x;
	int y = blockDim.y*blockIdx.y + threadIdx.y + rect.y;
	if(x < rect.z && y < rect.w) {
		kernel_filter_nlm_blur(x, y, differenceImage, outImage, rect, w, f);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_nlm_calc_weight(float ccl_readonly_ptr differenceImage, float *outImage, int4 rect, int w, int f) {
	int x = blockDim.x*blockIdx.x + threadIdx.x + rect.x;
	int y = blockDim.y*blockIdx.y + threadIdx.y + rect.y;
	if(x < rect.z && y < rect.w) {
		kernel_filter_nlm_calc_weight(x, y, differenceImage, outImage, rect, w, f);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_nlm_update_output(int dx, int dy,
                                     float ccl_readonly_ptr differenceImage,
                                     float ccl_readonly_ptr image,
                                     float *outImage, float *accumImage,
                                     int4 rect, int w,
                                     int f) {
	int x = blockDim.x*blockIdx.x + threadIdx.x + rect.x;
	int y = blockDim.y*blockIdx.y + threadIdx.y + rect.y;
	if(x < rect.z && y < rect.w) {
		kernel_filter_nlm_update_output(x, y, dx, dy, differenceImage, image, outImage, accumImage, rect, w, f);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_nlm_normalize(float *outImage, float ccl_readonly_ptr accumImage, int4 rect, int w) {
	int x = blockDim.x*blockIdx.x + threadIdx.x + rect.x;
	int y = blockDim.y*blockIdx.y + threadIdx.y + rect.y;
	if(x < rect.z && y < rect.w) {
		kernel_filter_nlm_normalize(x, y, outImage, accumImage, rect, w);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_nlm_construct_gramian(int dx, int dy,
                                         float ccl_readonly_ptr differenceImage,
                                         float ccl_readonly_ptr buffer,
                                         float *color_pass,
                                         float *variance_pass,
                                         float const* __restrict__ transform,
                                         int *rank,
                                         float *XtWX,
                                         float3 *XtWY,
                                         int4 rect,
                                         int4 filter_rect,
                                         int w, int h, int f) {
	int x = blockDim.x*blockIdx.x + threadIdx.x + max(0, rect.x-filter_rect.x);
	int y = blockDim.y*blockIdx.y + threadIdx.y + max(0, rect.y-filter_rect.y);
	if(x < min(filter_rect.z, rect.z-filter_rect.x) && y < min(filter_rect.w, rect.w-filter_rect.y)) {
		kernel_filter_nlm_construct_gramian(x, y, dx, dy, differenceImage, buffer, color_pass, variance_pass, transform, rank, XtWX, XtWY, rect, filter_rect, w, h, f);
	}
}

extern "C" __global__ void
CUDA_LAUNCH_BOUNDS(CUDA_THREADS_BLOCK_WIDTH, CUDA_KERNEL_MAX_REGISTERS)
kernel_cuda_filter_finalize(int w, int h,
                            float *buffer, int *rank,
                            float *XtWX, float3 *XtWY,
                            int4 filter_area, int4 buffer_params,
                            int sample) {
	int x = blockDim.x*blockIdx.x + threadIdx.x;
	int y = blockDim.y*blockIdx.y + threadIdx.y;
	if(x < filter_area.z && y < filter_area.w) {
		int storage_ofs = y*filter_area.z+x;
		rank += storage_ofs;
		XtWX += storage_ofs;
		XtWY += storage_ofs;
		kernel_filter_finalize(x, y, w, h, buffer, rank, filter_area.z*filter_area.w, XtWX, XtWY, buffer_params, sample);
	}
}

#endif

