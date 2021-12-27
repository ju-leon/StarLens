//
//  AverageStacking.metal
//  StarGazer
//
//  Created by Leon Jungemeyer on 26.12.21.
//

#include <CoreImage/CoreImage.h>

extern "C" { namespace coreimage {
  // 1
  float4 avgStacking(sample_t currentStack, sample_t newImage, float stackCount) {
    // 2
    //float4 avg = ((currentStack * stackCount) + newImage) / (stackCount + 1.0);
    float4 avg = max(currentStack, newImage);
      // 3
    avg = float4(avg.rgb, 1);
    // 4
    return avg;
  }
}}
