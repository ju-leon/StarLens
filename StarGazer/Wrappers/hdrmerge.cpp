//
//  hdrmerge.cpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 30.12.21.
//

#include "hdrmerge.hpp"
#include <fstream>

using namespace cv;

void hdrMerge(std::vector<cv::Mat> &images, cv::Mat &result) {
    /*
    Mat response;
    Ptr<CalibrateDebevec> calibrate = createCalibrateDebevec();
    calibrate->process(images, response, exposureTimes);
    
    Mat hdr;
    Ptr<MergeDebevec> merge_debevec = createMergeDebevec();
    merge_debevec->process(images, hdr, exposureTimes, response);
    
    Mat ldr;
    Ptr<Tonemap> tonemap = createTonemap(2.2f);
    tonemap->process(hdr, ldr);
    */
    Ptr<AlignMTB> alignMTB = createAlignMTB();
    //alignMTB->process(images, images);

    Ptr<MergeMertens> merge_mertens = createMergeMertens();
    merge_mertens->process(images, result);

}
