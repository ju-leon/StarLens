//
//  blend.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 15.01.22.
//

#ifndef blend_hpp
#define blend_hpp

#include <stdio.h>

using namespace std;
using namespace cv;

void blendLighten(Mat im1, Mat im2, Mat out);

void blendOverlay(Mat im1, Mat im2, Mat out);

void blendSoftLight(Mat im1, Mat im2, Mat out);

void blendHardLight(Mat im1, Mat im2, Mat out);

void applyMask(const Mat &inputImage, const Mat &mask, Mat &outputImage, int type = CV_8U);

#endif /* blend_hpp */
