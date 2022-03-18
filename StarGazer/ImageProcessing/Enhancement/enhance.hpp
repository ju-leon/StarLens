//
//  enhance.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 18.03.22.
//

#ifndef enhance_hpp
#define enhance_hpp

#include <stdio.h>

using namespace std;
using namespace cv;

void autoEnhance(const Mat &inputImage, Mat &outputImage);

void equalizeIntensity(const Mat& inputImage, Mat &outputImage);

void noiseReduction(const Mat& inputImage, Mat &outputImage, float intensity);

void reduceLightPollution(const Mat& inputImage, Mat &outputImage, float intensity);

void increaseStarBrightness(const Mat &inputImage, Mat outputImage, float intensity);
#endif /* enhance_hpp */
