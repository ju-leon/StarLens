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
import CoreLocation

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
    
    @State private var recordLocation = true
    @State private var showPermissionAlert = false
    
    @State private var applyMask = true
    @State private var shortExposure = true
    @State private var rawEnabled = true
    
    var body: some View {
        NavigationView {
                List {                   
                    Section(header: Text("General")) {
                        Toggle("Add GPS location to photo", isOn: $recordLocation).onChange(of: recordLocation, perform: {
                            _ in
                            
                            if recordLocation {
                                let manager = CLLocationManager()
                                switch manager.authorizationStatus {
                                case .restricted, .denied, .notDetermined:
                                    showPermissionAlert = true
                                    recordLocation = false
                                default:
                                    print("Permission ok")
                                }
                            }
                            DefaultsManager.saveBool(option: .recordLocation, state: recordLocation)
                        }).alert(isPresented: $showPermissionAlert) {
                            Alert(title: Text("Permission not granted"),
                                  message: Text("Go to Settings>Privacy>Location Services and allow StarLens to access your location to be able to save the location of an image."),
                                  dismissButton: .default(Text("OK"))
                            )
                        }
                        
                        Toggle("Show grid", isOn: .constant(false))
                    }
                    
                    Section(header: Text("Photo Settings"))  {
                        Picker(selection: $selectedImageQuality, label: Text("Photo Quality")) {
                            ForEach(0 ..< imageQualities.count) {
                                Text(self.imageQualities[$0])
                            }
                        }.onChange(of: selectedImageQuality, perform: {
                            _ in
                            DefaultsManager.saveInt(option: .imageQuality, state: selectedImageQuality)
                        })
                        
                        Toggle("Shoot RAW", isOn: $rawEnabled).onChange(of: rawEnabled, perform: {
                            _ in
                            DefaultsManager.saveBool(option: .rawEnabled, state: rawEnabled)
                        })
                    }

                    #if DEBUG
                        Section(header: Text("Debug")) {
                            Toggle("Short exposure", isOn: $shortExposure).onChange(of: shortExposure, perform: {
                                _ in
                                DebugManager.saveBool(option: .shortExposure, state: shortExposure)
                            })
                        }
                    #endif
                    
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
                            Text("beta-fs-0.0.1").opacity(0.8)
                        }
                        
                        #if DEBUG
                            Text("> DEBUG BUILD <")
                        #endif
                        
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
            self.selectedImageQuality = DefaultsManager.readInt(option: .imageQuality)
            self.selectedRawExport = DefaultsManager.readInt(option: .rawOption)
            self.applyMask = DefaultsManager.readBool(option: .isMaskEnabled)
            self.rawEnabled = DefaultsManager.readBool(option: .rawEnabled)
            self.recordLocation = DefaultsManager.readBool(option: .recordLocation)
        
            #if DEBUG
            self.shortExposure = DebugManager.readBool(option: .shortExposure)
            #endif
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
