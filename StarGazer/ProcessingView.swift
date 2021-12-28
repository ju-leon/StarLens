//
//  ProcessingView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 27.12.21.
//

import Foundation
import SwiftUI

class ResultModel : ObservableObject {
    var navigation: NavigationModel?
    
}

struct ResultView : View {
    @StateObject var model = ResultModel()
    
    @StateObject var navigationModel: NavigationModel
    
    var body: some View {
        GeometryReader { reader in
            ZStack{
                Color.black.edgesIgnoringSafeArea(.all)
                
                VStack {
                    Label("Top", systemImage: "trash").foregroundColor(.white)
                    
                }
            }
        }
    }
    
}
