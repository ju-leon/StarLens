//
//  StarMatcher.hpp
//  StarGazer
//
//  Created by Leon Jungemeyer on 11.03.22.
//

#ifndef StarMatcher_hpp
#define StarMatcher_hpp

#include <stdio.h>
#include <string.h>
#include <opencv2/opencv.hpp>
#include <fstream>
#include <chrono>
#include <algorithm>

using namespace cv;
using namespace std;

/**
 * Max allowed deviation percentage of two triangles to be classified a match
 */
const float MAX_DISTANCE_THRESHOLD = 0.01;

struct Constellation {
    int index;
    Point3f distances;

    Constellation(int index, const Point3f &distances) : index(index), distances(distances) {
    }

    /*
     * Returns the side length of the triangle
     */
    float length() {
        return distances.x + distances.y + distances.z;
    }
};

class StarMatcher {

private:
    vector<Constellation> baseConstellations;
    std::unique_ptr<cv::flann::GenericIndex<cv::flann::L2_Simple<float>>> constellationTree;

    /**
     Generate constellations betweem stars.
     @param maxTriagles Specifies the number of nearest neigbors considered for every star for constellation generation
     */
    void generateConstellations(vector<Point2i> &stars, vector<Constellation> &constellations, int knn = 10) {
        auto maxTriangles = knn < stars.size() ? knn : stars.size();
        /*
         Convert list of stars to features that can be passed to KNN Searcher
         */
        cv::Mat_<float> features(0, 2);
        for (auto &&point: stars) {
            cv::Mat row = (cv::Mat_<float>(1, 2) << point.x, point.y);
            features.push_back(row);
        }

        cv::flann::GenericIndex<cv::flann::L2<float>> starTree(features, cvflann::AutotunedIndexParams(),cv::flann::L2<float>());

        // Reserve space for constellations using Gauss formula
        int numberOfTriangles = (int) (stars.size() * stars.size());
        constellations.reserve(numberOfTriangles);

        /*
         Generate constellations.

         For every star, find the nearest neighbors and calculate the triangles between every pair
         of points and the base point.
         Triangles are always in following order:
          - Short side to base point
          - Long side to base point
          - Connection between outer points
         */
        for (int i = 0; i < stars.size(); i++) {
            std::vector<float> query;
            query.push_back(stars[i].x);
            query.push_back(stars[i].y);
            std::vector<int> indices(maxTriangles);
            std::vector<float> dists(maxTriangles);
            starTree.knnSearch(query, indices, dists, maxTriangles, cvflann::SearchParams(128));

            // Calculate distances between every pair of points
            // The "closest" point will always be the point we're querying from, so we skip it (start from 1)
            for (int j = 1; j < indices.size(); j++) {
                for (int k = j + 1; k < indices.size(); k++) {
                    // Should never happen...
                    if (indices[j] == indices[k]) {
                        continue;
                    }
                    // Calculate the distance between the two outer points
                    int dist = sqrt(pow(stars[indices[j]].x - stars[indices[k]].x, 2) + pow(stars[indices[j]].y - stars[indices[k]].y, 2));

                    // Make sure the order if the sides is always the same
                    auto shortDistance = dists[j] < dists[k] ? dists[j] : dists[k];
                    auto longDistance = dists[j] < dists[k] ? dists[k] : dists[j];

                    // OpenCV returns squared euclidean distances, so we need to take the square root
                    shortDistance = sqrt(shortDistance);
                    longDistance = sqrt(longDistance);

                    // Add the constellation to the list
                    constellations.push_back(Constellation(i, Point3f(shortDistance, longDistance, dist)));
                }
            }
        }

    }

public:
    StarMatcher(vector<Point2i> &stars) {
        generateConstellations(stars, baseConstellations, 5);

        cv::Mat_<float> features(0, 3);
        for (auto &constellation: baseConstellations) {
            cv::Mat row = (cv::Mat_<float>(1, 3)
                    << constellation.distances.x, constellation.distances.y, constellation.distances.z);
            features.push_back(row);
        }
        constellationTree = std::make_unique<cv::flann::GenericIndex<cv::flann::L2_Simple<float>>>(features, cvflann::KDTreeIndexParams());

    }

    void matchStars(vector<Point2i> &stars, vector<DMatch> &matches) {
        vector<Constellation> constellations;
        generateConstellations(stars, constellations, 3);

        for (auto &constellation: constellations) {
            // Query the closest base constellation for every new constellation
            std::vector<float> query;
            query.push_back(constellation.distances.x);
            query.push_back(constellation.distances.y);
            query.push_back(constellation.distances.z);
            std::vector<int> indices(1);
            std::vector<float> dists(1);
            constellationTree->knnSearch(query, indices, dists, 1, cvflann::SearchParams());

            // Add the match to the list if the distance is smaller than the threshold
            if (dists[0] < constellation.length() * MAX_DISTANCE_THRESHOLD) {
                matches.push_back(DMatch(baseConstellations[indices[0]].index, constellation.index, dists[0]));
            }

        }
    }

};

#endif /* StarMatcher_hpp */
