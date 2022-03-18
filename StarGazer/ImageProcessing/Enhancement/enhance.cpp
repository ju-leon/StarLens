//
//  enhance.cpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 18.03.22.
//

#include "enhance.hpp"

void autoEnhance(const Mat &inputImage, Mat &outputImage) {
    equalizeIntensity(inputImage, outputImage);
}


/**
 Applies CLAHE to all channels.
 @param inputImage 3-channel 8U Mat with RGB channel ordering
 */
void equalizeIntensity(const Mat& inputImage, Mat &outputImage)
{
    Mat ycrcb;

    cvtColor(inputImage,ycrcb,COLOR_RGB2Lab);
    
    vector<Mat> channels;
    split(ycrcb,channels);

    auto clahe = createCLAHE(1.5, cv::Size(8,8));
    
    clahe->apply(channels[0], channels[0]);
    
    clahe->setClipLimit(0.5);
    
    clahe->apply(channels[1], channels[1]);
    clahe->apply(channels[2], channels[2]);

    Mat result;
    merge(channels,ycrcb);

    cvtColor(ycrcb,outputImage,COLOR_Lab2RGB);

}

/**
 Applies noise reduction to an image. Intensity should be >0
 */
void noiseReduction(const Mat& inputImage, Mat &outputImage, float intensity = 3) {
    fastNlMeansDenoisingColored(inputImage, outputImage, intensity);
}


/**
 Reduces background noise in an image
 */
void reduceLightPollution(const Mat &inputImage, Mat &outputImage, float intensity) {
    //Estimate light pollution from image
    Mat pollution;
    cv::blur(inputImage, pollution, Size(200, 200), cv::Point(-1, -1), BORDER_REPLICATE);

    pollution *= intensity;
    
    // Subtract light pollution from image
    cv::subtract(inputImage, pollution, outputImage);

}


void increaseStarBrightness(const Mat &inputImage, Mat outputImage, float intensity) {
    
}

