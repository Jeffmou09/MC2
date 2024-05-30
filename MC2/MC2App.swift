//
//  MC2App.swift
//  MC2
//
//  Created by Jefferson Mourent on 17/05/24.
//

import SwiftUI
import SwiftData

@main
struct MC2App: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: DataItem.self)
    }
}
