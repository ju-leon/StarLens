//
//  foreground.cpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 30.12.21.
//

#include "foreground.hpp"
#include <fstream>

using namespace cv;

/**
 Returns a mask only containing moving objects in a scene.
 */
void findForeground(cv::Mat &foreground, std::vector<cv::Mat> &sequence) {
    //cvtColor(sequence[0], foreground, COLOR_BGR2GRAY);

    foreground = Mat::zeros(sequence[0].rows,
            sequence[0].cols,
            CV_8UC1);

    Ptr<cv::BackgroundSubtractor> bgSub = createBackgroundSubtractorMOG2();

    bool first = true;

    for (Mat &frame: sequence) {
        Mat gray;
        cvtColor(frame, gray, COLOR_BGR2GRAY);

        Mat fgMask;
        bgSub->apply(gray, fgMask);

        if (first) {
            // Don't includ the first image since everything will move
            first = false;
        } else {
            addWeighted(foreground, 1.0, fgMask, 1.0, 0.0, foreground);
        }
    }

    auto kernel = getStructuringElement(MORPH_RECT, Size(10, 10));
    morphologyEx(foreground, foreground, MORPH_ERODE, kernel);
    threshold(foreground, foreground, 30, 255, THRESH_BINARY);
}
