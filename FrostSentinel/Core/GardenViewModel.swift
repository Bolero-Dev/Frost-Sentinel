//
//  GardenViewModel.swift
//  FrostSentinel
//
//  Orchestrates the three layers: REST forecast (Swift async), Core Data
//  cache (offline-first), and the legacy Objective-C frost calculator.
//

import Foundation
import Combine
import CoreData

/// The answer for one plant tonight.
struct PlantVerdict: Identifiable {
    let id: UUID
    let plantName: String
    let risk: FSFrostRisk
    let advice: String
    let marginC: Double
}

@MainActor
final class GardenViewModel: ObservableObject {

    enum DataSource: Equatable {
        case live
        case cache(fetchedAt: Date)
        case none
    }

    @Published private(set) var verdicts: [PlantVerdict] = []
    @Published private(set) var tonightMinC: Double?
    @Published private(set) var dataSource: DataSource = .none
    @Published private(set) var errorMessage: String?

    private let store: GardenStore
    private let forecastService: ForecastFetching
    private let calculator = FSFrostCalculator()

    init(store: GardenStore, forecastService: ForecastFetching? = nil) {
        self.store = store
        self.forecastService = forecastService ?? OpenMeteoForecastService()
    }

    /// Offline-first refresh:
    /// 1. Try the network; on success, cache the result.
    /// 2. On failure, fall back to the Core Data cache and say so —
    ///    a slightly stale answer beats no answer when frost is coming.
    func refresh(latitude: Double, longitude: Double) async {
        errorMessage = nil

        do {
            let nights = try await forecastService.nightlyMinimums(
                latitude: latitude, longitude: longitude, days: 3
            )
            try store.replaceForecastCache(with: nights)
            dataSource = .live
            evaluate(nights: nights)
        } catch {
            do {
                let cached = try store.cachedForecast()
                if cached.isEmpty {
                    dataSource = .none
                    errorMessage = "Couldn't reach the forecast service, and no cached forecast exists yet."
                } else {
                    let fetchedAt = (try? store.cacheFetchedAt()) ?? nil
                    dataSource = .cache(fetchedAt: fetchedAt ?? .distantPast)
                    evaluate(nights: cached)
                }
            } catch {
                dataSource = .none
                errorMessage = "Couldn't load the cached forecast: \(error.localizedDescription)"
            }
        }
    }

    /// Re-runs verdicts without refetching (e.g. after adding a plant).
    func reevaluate() {
        if let cached = try? store.cachedForecast(), !cached.isEmpty {
            evaluate(nights: cached)
        }
    }

    // MARK: - Verdicts

    private func evaluate(nights: [NightForecast]) {
        guard let tonight = nights.first else {
            verdicts = []
            tonightMinC = nil
            return
        }

        tonightMinC = tonight.minTempC

        let plants = (try? store.plants()) ?? []
        verdicts = plants.map { plant in
            // Legacy Objective-C layer doing the domain math, bridged into Swift.
            let risk = calculator.risk(
                forForecastMinCelsius: tonight.minTempC,
                toleranceCelsius: plant.toleranceCelsius
            )
            return PlantVerdict(
                id: plant.id,
                plantName: plant.name,
                risk: risk,
                advice: calculator.advice(for: risk, plantName: plant.name),
                marginC: calculator.margin(
                    forForecastMinCelsius: tonight.minTempC,
                    toleranceCelsius: plant.toleranceCelsius
                )
            )
        }
        // Most at-risk plants first: the answer you need is at the top.
        .sorted { $0.risk.rawValue > $1.risk.rawValue }
    }
}
