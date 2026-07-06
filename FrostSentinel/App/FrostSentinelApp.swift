//
//  FrostSentinelApp.swift
//  FrostSentinel
//
//  One question, answered quietly: does anything in my garden need
//  covering tonight?
//

import SwiftUI

@main
struct FrostSentinelApp: App {
    private let persistence = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            GardenView(
                viewModel: GardenViewModel(
                    store: GardenStore(context: persistence.viewContext)
                ),
                store: GardenStore(context: persistence.viewContext)
            )
        }
    }
}
