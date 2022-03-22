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
import ModalView

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
    @State var onDone: () -> ()

    let interfaceQueue: DispatchQueue = DispatchQueue(label: "StarStacker.defaultsQueue")
    let defaults = UserDefaults.standard
    
    var imageQualities = ["Medium", "High", "Very High"]
    @State private var selectedImageQuality = 2
    
    var rawOptions = ["Combined", "Background + Foreground", "Background + Foreground + Mask"]
    @State private var selectedRawExport = 0
    
    @State private var applyMask = true
    @State private var shortExposure = true
    @State private var rawEnabled = true
    
    func saveDefault(key: UserOption, value: Any) {
        defaults.set(value, forKey: key.rawValue)
    }
    
    var body: some View {
        NavigationView {
                List {                   
                    Section(header: Text("General")) {
                        Toggle("Add GPS location to photo", isOn: .constant(true))
                        
                        Toggle("Show grid", isOn: .constant(false))
                    }
                    
                    Section(header: Text("Photo Settings"))  {
                        Picker(selection: $selectedImageQuality, label: Text("Photo Quality")) {
                            ForEach(0 ..< imageQualities.count) {
                                Text(self.imageQualities[$0])
                            }
                        }.onChange(of: selectedImageQuality, perform: {
                            _ in saveDefault(key: .imageQuality, value: selectedImageQuality)
                        })
                        
                        Picker(selection: $selectedRawExport, label: Text("RAW Export")) {
                            ForEach(0 ..< rawOptions.count) {
                                Text(self.rawOptions[$0])
                            }
                        }.onChange(of: selectedRawExport, perform: {
                            _ in saveDefault(key: .rawOption, value: selectedRawExport)
                        })
                        
                    }

                    
                    Section(header: Text("Experimental"), footer: Text("This will keep all captured images, even after processing. Projects will be very large. Only use if you have use for the raw, unstacked images.")) {
                        Toggle("Keep unstacked images", isOn: .constant(true))
                    }
                    
                    Section(header: Text("Debug")) {
                        Toggle("Apply mask", isOn: $applyMask).onChange(of: applyMask, perform: {
                            _ in
                            saveDefault(key: .isMaskEnabled, value: applyMask)
                        })
                        
                        Toggle("Short exposure", isOn: $shortExposure).onChange(of: shortExposure, perform: {
                            _ in
                            saveDefault(key: .shortExposure, value: shortExposure)
                        })
                        
                        Toggle("Shoot RAW", isOn: $rawEnabled).onChange(of: rawEnabled, perform: {
                            _ in
                            saveDefault(key: .rawEnabled, value: rawEnabled)
                        })
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
                            Text("alpha-0.0.2").opacity(0.8)
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
                .navigationTitle("Settings")
                .navigationBarItems(trailing:
                    Button(action: {
                        onDone()
                    }, label:{
                        Text("Done")
                    })
                )
                 
        }.onAppear(perform: {
            self.selectedImageQuality = defaults.integer(forKey: UserOption.imageQuality.rawValue)
            self.selectedRawExport = defaults.integer(forKey: UserOption.rawOption.rawValue)
            self.applyMask = defaults.bool(forKey: UserOption.isMaskEnabled.rawValue)
            self.shortExposure = defaults.bool(forKey: UserOption.shortExposure.rawValue)
            self.rawEnabled = defaults.bool(forKey: UserOption.rawEnabled.rawValue)
        })
        
    }
    
}


struct Licenses: View {
    var body: some View {
        List {
            Section(header: Text("OpenCV")) {
                Text("""
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

            Section(header: Text("Lottie")) {
                Text("""
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
