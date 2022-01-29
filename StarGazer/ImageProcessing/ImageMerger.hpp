//
//  ImageMerger.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 29.01.22.
//

#ifndef ImageMerger_hpp
#define ImageMerger_hpp

#include <stdio.h>
#include <opencv2/opencv.hpp>

using namespace std;
using namespace cv;

class ImageMerger {
private:
    bool firstImageAdded = false
    
    /**
    Current stack all future aligned images will be merged on
     */
    Mat currentStack;
    
    float threshold;
    Mat lastImage;
    vector<Point2i> lastStars;
public:
    ImageMerger() {
        
    }
    
    Mat mergeImageOnStack(Mat &image, Mat &mask) {
        if (!firstImageAdded) {
            threshold = getThreshold(image);
            //TODO: What happens if threh is invalid(infinity?)
            
            
        }
    }
};

#endif /* ImageMerger_hpp */
