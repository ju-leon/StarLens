//
//  ProcessingView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 27.12.21.
//

import SwiftUI
import Combine
import AVFoundation
import UIKit

struct ProcessingView : View {
    @Binding var numFailed : Int
    @Binding var numProcessed : Int
    @Binding var numPictures : Int

    @Binding var photo: UIImage

    @State var cancelProcessing: () -> ()

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Label(String(numPictures), systemImage: "sparkles.rectangle.stack").foregroundColor(.white)
                Spacer()
                Label(String(numProcessed), systemImage: "checkmark.circle").foregroundColor(.white)
                Spacer()
                Label(String(numFailed), systemImage: "xmark.circle").foregroundColor(.white)
                Spacer()
            }

            Spacer()
            Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipped()
            Spacer()

            ProgressView("Stacking Images…", value: Float(numFailed + numProcessed) / Float(numPictures))
                    .foregroundColor(.white)
                    .padding(.all)
                    .animation(.easeInOut)

            Button("Process later...") {
                cancelProcessing()
            }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(40)

            Spacer()


        }
    }

}