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

final class ProcessingModel : ObservableObject {
    @Published var photoStack: PhotoStack?
    
    @Published var numPicures = 0
    @Published var numProcessed = 0
    @Published var numFailed = 0
    @Published var coverPhoto = UIImage()
    
    var navigation: StateControlModel?
    
    private var subscriptions = Set<AnyCancellable>()

    init(photoStack: PhotoStack?) {
        self.photoStack = photoStack
        /*
        self.photoStack?.$numPicures.sink { [weak self] (val) in
                    self?.numPicures = val
                }
                .store(in: &self.subscriptions)
        
        self.photoStack?.$numProcessed.sink { [weak self] (val) in
                    self?.numProcessed = val
                }
                .store(in: &self.subscriptions)

        self.photoStack?.$numFailed.sink { [weak self] (val) in
                    self?.numFailed = val
                }
                .store(in: &self.subscriptions)
        
        self.photoStack?.$coverPhoto.sink { [weak self] (val) in
                    self?.coverPhoto = val
                }
                .store(in: &self.subscriptions)*/
    }
}

struct ProcessingView : View {
    @StateObject var processingModel: ProcessingModel
    @StateObject var navigationModel: StateControlModel
    
    
    var body: some View {
        GeometryReader { reader in
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Label(String(processingModel.numPicures), systemImage: "sparkles.rectangle.stack").foregroundColor(.white)
                    Spacer()
                    Label(String(processingModel.numProcessed), systemImage: "checkmark.circle").foregroundColor(.white)
                    Spacer()
                    Label(String(processingModel.numFailed), systemImage: "xmark.circle").foregroundColor(.white)
                    Spacer()
                }
                
                Spacer()
                Image(uiImage: processingModel.coverPhoto)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipped()
                Spacer()
                VStack {
                    ProgressView("Stacking Images…", value: Float(processingModel.numProcessed + processingModel.numFailed) / Float(processingModel.numPicures))
                            .foregroundColor(.white)
                            .padding(.all)
                            .animation(.easeInOut)

                    Button("Process later...") {}
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.accentColor)
                        .cornerRadius(40)
                }
                Spacer()
                
            }
        }
    }
    
}
