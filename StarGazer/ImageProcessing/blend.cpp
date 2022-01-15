//
//  blend.cpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 15.01.22.
//

#include "blend.hpp"


void blendLighten(Mat im1, Mat im2, Mat out) {
    cv::max(im1, im2, out);
}

void blendOverlay(Mat im1, Mat im2, Mat out) {
    Mat ov1, ov2;
    
    ov1 = 1 - (1-2*(im1 - 0.5)) * (1 - im2);
    ov2 = (2 * im1) * im2;
    
    out.setTo(ov1, im1 > 0.5);
    out.setTo(ov1, im1 <= 0.5);
}

void blendSoftLight(Mat im1, Mat im2, Mat out) {
    Mat ov1, ov2;
    
    ov1 = 1 - ((1-im1) * (1 - (im2 - 0.5)));
    ov2 = im1 * (im2 + 0.5);
    
    out.setTo(ov1, im2 > 0.5);
    out.setTo(ov1, im2 <= 0.5);
}

void blendHardLight(Mat im1, Mat im2, Mat out) {
    Mat ov1, ov2;
    
    ov1 = 1 - ((1-im1) * (1 - (im2 - 0.5)));
    ov2 = im1 * (im2 + 0.5);
    
    out.setTo(ov1, im2 > 0.5);
    out.setTo(ov1, im2 <= 0.5);
}
