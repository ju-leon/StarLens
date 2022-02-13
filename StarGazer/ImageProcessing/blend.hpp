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

void blendMasked(Mat &sky, Mat &foreground, Mat &mask, Mat &output);

#endif /* blend_hpp */
