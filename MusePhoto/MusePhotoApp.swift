//
//  MusePhotoApp.swift
//  MusePhoto
//
//  Created by machu on 2026/05/27.
//

import SwiftUI
import SwiftData

@main
struct MusePhotoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ExhibitionRecord.self])
    }
}
