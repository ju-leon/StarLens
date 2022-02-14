//
//  SettingsView.swift
//  StarGazer
//
//  Created by Leon Jungemeyer on 14.02.22.
//

import Foundation
import SwiftUI
import Combine
import AVFoundation
import UIKit
import SlidingRuler

struct SwitchTask: View {
    @State var text: String
    @State var enabled: Bool
    
    var body: some View {
        HStack {
            Toggle(text, isOn: $enabled)
            
        }
    }
}

struct SettingsView : View {    
    @StateObject var navigationModel: StateControlModel

    @State var enabled = true
    
    var body: some View {
        NavigationView {
                List {
                    Button(action: {
                        withAnimation {
                            navigationModel.currentView = .camera
                        }
                    }){Text("Done")}
                    
                    Section(header: Text("General")) {
                        Toggle("Add GPS location to photo", isOn: .constant(true))
                        
                        Toggle("Show grid", isOn: .constant(true))
                    }
                    
                    Section(header: Text("Advanced")) {
                        Toggle("Test", isOn: .constant(true))
                        Text("Item 2")
                        Text("Item 3")
                    }
                    
                    Section(header: Text("Experimental"), footer: Text("This will keep all captured images, even after processing. Projects will be very large. Only use if you have use for the raw, unstacked images.")) {
                        Toggle("Keep unstacked images", isOn: .constant(true))
                    }
                    
                    Section(header: Text("About"),
                            footer: VStack{
                        Text("© 2022, Leon Jungemeyer").frame(maxWidth: .infinity, alignment: .center)
                        Text("All rights reserved.").frame(maxWidth: .infinity, alignment: .center)
                    }) {
                        Button(action: {}){ Text("Rate in AppStore")}
                        Button(action: {}){ Text("Contact")}
                        
                        HStack {
                            Text("Version")

                            Spacer()
                            Text("alpha-0.0.1").opacity(0.8)
                        }
                        
                        NavigationLink(destination: Licenses()) {
                            Text("Licenses used")
                        }
                        
                        //Text("OpenCV")
                        //Text("LibRaw")
                        //Text("Tensorflow")
                        //Text("PyTorch")
                    }
                    
                    
                }
                //TODO: WWhy does this cause issues??
                //.navigationTitle("Settings")
                .listStyle(InsetGroupedListStyle())
                 
            }
        
    }
    
}


struct Licenses: View {
    var body: some View {
        List {
            Section(header: Text("OpenCV")) {
                Text("""
                     Copyright 2022 Leon Jungemeyer
                     
                     Licensed under the Apache License, Version 2.0 (the "License");
                     you may not use this file except in compliance with the License.
                     You may obtain a copy of the License at

                         http://www.apache.org/licenses/LICENSE-2.0

                     Unless required by applicable law or agreed to in writing, software
                     distributed under the License is distributed on an "AS IS" BASIS,
                     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
                     See the License for the specific language governing permissions and
                     limitations under the License.
                     """)
            }
            
        }
        .navigationTitle("Licenses")
        .listStyle(InsetGroupedListStyle())
         
    }
    
}
