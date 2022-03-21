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
    
    cvtColor(outputImage,ycrcb,COLOR_RGB2YCrCb);
    
    vector<Mat> channels;
    split(ycrcb,channels);

    
    auto clahe = createCLAHE(1.5, cv::Size(8,8));
    
    clahe->apply(channels[0], channels[0]);
    
    clahe->setClipLimit(0.5);
    
    //clahe->apply(channels[1], channels[1]);
    //clahe->apply(channels[2], channels[2]);
    
    merge(channels,ycrcb);

    cvtColor(ycrcb,outputImage,COLOR_YCrCb2RGB);
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
    
    outputImage = outputImage * (intensity + 1);
}


void increaseStarBrightness(const Mat &inputImage, Mat outputImage, float intensity, float colorCorrection) {
    inputImage /= 256;
    cvtColor(inputImage, outputImage, COLOR_RGB2HSV);

    vector<Mat> channels;
    split(outputImage,channels);
    
    channels[0] = channels[0] * colorCorrection;
    channels[1] = channels[1] * (intensity + 1);
    
    Mat result;
    merge(channels,outputImage);

    cvtColor(outputImage, outputImage, COLOR_HSV2RGB);
    outputImage *= 256;
    
}

