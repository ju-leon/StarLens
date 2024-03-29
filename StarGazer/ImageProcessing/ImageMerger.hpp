//
//  ImageMerger.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 29.01.22.
//

#ifndef ImageMerger_hpp
#define ImageMerger_hpp

#include <stdio.h>
#include <string.h>
#include <opencv2/opencv.hpp>
#include <fstream>
#include <chrono>

#include "StarMatcher.hpp"
#include "SaveBinaryCV.hpp"
#include "blend.hpp"
#include "enhance.hpp"

#define CHECKPOINT_FILENAME "/checkpoint.stargazer"
#define METADATA_FILENAME "/checkpoint.meta"

using namespace std;
using namespace cv;

struct MergingException : public exception {
    const char *info;

    MergingException(const char *info) : info(info) {
    }

    const char *what() const throw() {
        return info;
    }
};

class ImageMerger {
private:
    /**
     * Number of stars required in an image to start matching
     */
    const int MIN_STARS_PER_IMAGE = 5;

    /**
     * Minimum stars matched in a new image to be added to the stack
     */
    const int MIN_MATCHED_STARS =  5;

    /**
     * Threshold user which brute force matcher will be used.
     */
    const int SIMPLE_MATCHER_THRESHOLD = 500;

    bool firstImageAdded = false;

    /**
    Current stack all future aligned images will be merged on.
    Images will be added so they can be averaged later.
     */
    Mat currentCombined;

    /**
    Current stack all imges will be merged onto.
    Images are merged onto the stack using a max operation, so the stack contains the max over all images.
     */
    Mat currentMaxed;
    
    /**
    Current stack all imges will be merged onto.
    Images are merged onto the stack without being aligned. Used to spereate foreground and background.
     */
    Mat currentStacked;

    /**
    Mask that seperates fromground from backgrounds in the image.
     */
    Mat foregroundMask;
    
    int numImages;
    int numFailed;

    float threshold;

    Mat totalHomography;

    Mat lastImage;

    vector<Point2i> lastStars;

    /**
    Toggles if the stars will be rendered onto the image
     */
    bool visualiseTrackingPoints;
    
    /**
     Mat containing the stars if visualiseTrackingPoints is enabled
     */
    Mat starContours;
    
    /**
    Determinat used to continously monitor stacking. Determinat should only change slightly between frames.
     */
    double currentDeterminant = 1.0;
    
    /**
     Matcher used to align new images.
     Needs to be intialized at the beginning of the process.
     */
    std::unique_ptr<StarMatcher> matcher;

public:
    /**
     * Creates a new image merger and tries to initialize all values.
     * If not enough features are found ion the initial image, an exception is thrown.
     * @param image
     */
    ImageMerger(Mat &image, Mat &segmentation, bool visualiseTrackingPoints = false) : visualiseTrackingPoints(visualiseTrackingPoints) {
        Mat imageMasked;
        
        if (!segmentation.empty()) {
            createTrackingMask(segmentation, foregroundMask);
            resize(foregroundMask, foregroundMask, image.size(), 0, 0, INTER_LINEAR);
            
            // Apply mask to image.
            applyMask(image, foregroundMask, imageMasked);
        } else {
            image.copyTo(imageMasked);
        }
        
        // Find an initial threshold to be used in future images
        std::cout << "Finding initial threshold..." << std::endl;
        threshold = getThreshold(imageMasked);
        std::cout << "Initial threshold: " << threshold << std::endl;
        if (threshold == numeric_limits<float>::infinity()) {
            throw MergingException("Could not find initial threshold");
        }

        std::cout << "Finding initial stars..." << std::endl;
        //Find the star centers for the first image
        Mat contour;
        getStarCenters(imageMasked, threshold, contour, lastStars);
        std::cout << "Found " << lastStars.size() << " stars" << std::endl;

        if (lastStars.size() < MIN_STARS_PER_IMAGE) {
            throw MergingException("Not enough stars found in initial image");
        }

        // Initialize the matcher
        matcher = std::make_unique<StarMatcher>(lastStars);

        // Initialize the current stacks
        image.copyTo(lastImage);
        lastImage.convertTo(currentCombined, CV_16U);
        lastImage.convertTo(currentStacked, CV_16U);

        currentMaxed = image.clone();

        // Init the total homography matrix as identity
        totalHomography = Mat::eye(3, 3, CV_64FC1);

        size_t sizeInBytes = currentCombined.total() * currentCombined.elemSize();
        std::cout << "Size in bytes: " << sizeInBytes << std::endl;
        
        numImages = 1;
        numFailed = 0;
    }
    
    /**
     Continue processing from a previously saved checkpoint
     */
    ImageMerger(string checkpoint, int numImages, bool visualiseTrackingPoints = false) : visualiseTrackingPoints(visualiseTrackingPoints) {
        std::cout << "Checkpoint path: " << checkpoint + CHECKPOINT_FILENAME << std::endl;
        
        std::ifstream ifs(checkpoint + CHECKPOINT_FILENAME, std::ios::binary);

        readMatBinary(ifs, currentCombined);
        currentCombined.convertTo(currentCombined, CV_16U);
        
        readMatBinary(ifs, currentMaxed);
        currentMaxed.convertTo(currentMaxed, CV_8U);
        
        readMatBinary(ifs, currentStacked);
        currentStacked.convertTo(currentStacked, CV_16U);
        
        readMatBinary(ifs, foregroundMask);
        foregroundMask.convertTo(foregroundMask, CV_32F);
        
        this->numImages = numImages;
        numFailed = 0;
    }

    virtual ~ImageMerger() {
        std::cout << "Image merger destructor called" << std::endl;
    }

    /**
     * Calculates a preview of the current stack.
     * @param previewImage
     */
    void getPreview(Mat &previewImage) {
        //previewImage = currentMaxed;
        previewImage = currentMaxed.clone();
        
        if (visualiseTrackingPoints) {
            std::cout << "added contours" << std::endl;
            if (!starContours.empty()) {
                addWeighted(previewImage, 0.5, starContours, 5, 0.0, previewImage);
            }
        }
    } 

    /**
     * Returns the processed image.
     */
    void getProcessed(Mat &image) {
        if (!foregroundMask.empty()) {
            Mat combinedNormal = currentCombined / numImages;
            Mat stackedNormal = currentStacked / numImages;
            
            combinedNormal.convertTo(combinedNormal, CV_8UC3);
            applyMask(combinedNormal, foregroundMask, combinedNormal);
            
            stackedNormal.convertTo(stackedNormal, CV_8UC3);
            applyMask(stackedNormal, 1 - foregroundMask, stackedNormal);
                  
            addWeighted(combinedNormal, 1, stackedNormal, 1, 0, image);

            autoEnhance(image, image);
            
            //blendMasked(combinedNormal, stackedNormal, foregroundMask, image);
        } else {
            Mat combinedNormal = currentCombined / numImages;
            combinedNormal.convertTo(image, CV_8UC3);
        }
    }

    /**
     * Tries to merge an image on top of the current stack.
     * Aligns the image if enough stars are found.
     * @param image Image to be merged
     * @param preview A preview of the current stack will be copied to here.
     * @return True if the operation was successful, false otherwise.
     */
    bool mergeImageOnStack(Mat &image, Mat &preview) {
        Mat imageMasked;
        if (!foregroundMask.empty()) {
            // Apply mask to image.
            applyMask(image, foregroundMask, imageMasked);
        } else {
            image.copyTo(imageMasked);
        }
        
        // Compute the stars in the current image
        vector<Point2i> stars;
        Mat contours;
        threshold = getStarCenters(imageMasked, threshold, contours, stars);
        
        if (stars.size() < MIN_STARS_PER_IMAGE) {
            std::cout << "Not enough stars found" << std::endl;
            numFailed++;
            getPreview(preview);
            return false;
        }

        // Match the stars with the last image
        vector<DMatch> matches;
        std::cout << "Last star size: " << lastStars.size() << ", new stars size: " << stars.size() << std::endl;

        /*
        if (std::max(lastStars.size(), stars.size()) > SIMPLE_MATCHER_THRESHOLD) {
            matchStars(lastStars, stars, matches);
        } else {
            matchStarsSimple(lastStars, stars, matches);
        }
         */
        Mat featureVis = Mat::zeros(imageMasked.rows, imageMasked.cols, CV_8UC1);
        matcher->matchStars(stars, matches, featureVis);


        // Extract the star centers from the matches
        std::vector<Point2i> matched_points1, matched_points2;
        for (size_t i = 0; i < matches.size(); i++) {
            matched_points1.push_back(lastStars[matches[i].queryIdx]);
            matched_points2.push_back(stars[matches[i].trainIdx]);
        }

        if (matched_points1.size() < MIN_MATCHED_STARS || matched_points2.size() < MIN_MATCHED_STARS) {
            std::cout << "Not enough stars could be matched" << std::endl;
            numFailed++;
            getPreview(preview);
            return false;
        }

        std::cout << "Found " << matched_points1.size() << " points to match" << std::endl;

        // Find homography
        auto h = findHomography(matched_points2, matched_points1, RANSAC, 3, noArray(), 2000, 0.995);

        // If no homography was found, return
        if (h.empty()) {
            std::cout << "No homography found" << std::endl;
            numFailed++;
            getPreview(preview);
            return false;
        }

        // Homogrpahies should always (almost) perserve the size of an image -> det around 1
        auto ratio = cv::determinant(h) / currentDeterminant;
        std::cout << "Determinat ratio: " << ratio << std::endl;
        
        if (ratio < 0.9 || ratio > 1.1) {
            std::cout << "Homography scale invalid" << std::endl;
            numFailed++;
            getPreview(preview);
            return false;
        }
        currentDeterminant = cv::determinant(h);
        
        // Append to the current total homography
        totalHomography = totalHomography * h;
        
        // Use homography to warp image, set border of aligned image to pixel average of the sky
        auto average = cv::mean(imageMasked);
        Mat alignedImage;
        warpPerspective(image, alignedImage, h, imageMasked.size(), INTER_LINEAR, BORDER_CONSTANT, average);
        
        /**
         Create a visulaisation of the current tracking points if requested
         */
        if (visualiseTrackingPoints) {
            std::vector<cv::Mat> channels(3);
            channels.at(0) = contours;
            channels.at(1) = featureVis;
            channels.at(2) = featureVis;
            
            cv::merge(channels, starContours);
            //warpPerspective(starContours, starContours, h, featureVis.size());
        }
                
        max(currentMaxed, alignedImage, currentMaxed);

        // Add image to the current stacks
        alignedImage.convertTo(alignedImage, CV_16U);
        addWeighted(currentCombined, 1, alignedImage, 1, 0.0, currentCombined, CV_16U);

        // Add image without alignment
        Mat doubleImage;
        image.convertTo(doubleImage, CV_16U);
        addWeighted(currentStacked, 1, doubleImage, 1, 0.0, currentStacked, CV_16U);
        
        
        // Update last image and stars
        lastImage = image;
        
        
        //lastStars = stars;
        numImages++;

        getPreview(preview);

        return true;
    }

    
    void saveToDirectory(string dir) {
        // Save combined
        std::ofstream ofs(dir + CHECKPOINT_FILENAME, std::ios::binary);
        writeMatBinary(ofs, currentCombined);
        writeMatBinary(ofs, currentMaxed);
        writeMatBinary(ofs, currentStacked);
        writeMatBinary(ofs, foregroundMask);
    }

};

#endif /* ImageMerger_hpp */
