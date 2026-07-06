//
//  GardenViewModelTests.swift
//  FrostSentinelTests
//
//  Integration tests across all three layers: a mocked REST service,
//  a real in-memory Core Data stack, and the bridged Objective-C calculator.
//

import Foundation
import Testing
@testable import FrostSentinel

// MARK: - Mock forecast service

struct MockForecastService: ForecastFetching {
    var result: Result<[NightForecast], Error>

    func nightlyMinimums(latitude: Double, longitude: Double, days: Int) async throws -> [NightForecast] {
        try result.get()
    }
}

private func night(_ minTempC: Double, daysFromNow: Int = 0) -> NightForecast {
    NightForecast(
        date: Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now)!,
        minTempC: minTempC
    )
}

// MARK: - Tests

@MainActor
struct GardenViewModelTests {

    private func makeStore() -> GardenStore {
        GardenStore(context: PersistenceController(inMemory: true).viewContext)
    }

    @Test func liveForecastProducesVerdictsSortedByRisk() async throws {
        let store = makeStore()
        try store.addPlant(name: "Basil", toleranceCelsius: 5)      // tender
        try store.addPlant(name: "Lavender", toleranceCelsius: -15) // hardy

        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .success([night(1.0)]))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        #expect(viewModel.dataSource == .live)
        #expect(viewModel.tonightMinC == 1.0)
        #expect(viewModel.verdicts.count == 2)

        // Basil (1.0 vs 5.0 tolerance = frost risk) must sort above Lavender (safe).
        #expect(viewModel.verdicts.first?.plantName == "Basil")
        #expect(viewModel.verdicts.first?.risk == .frost)
        #expect(viewModel.verdicts.last?.risk == .none)
    }

    @Test func successfulFetchPopulatesTheCache() async throws {
        let store = makeStore()
        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .success([night(2.5), night(3.0, daysFromNow: 1)]))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        let cached = try store.cachedForecast()
        #expect(cached.count == 2)
        #expect(cached.first?.minTempC == 2.5)
    }

    @Test func networkFailureFallsBackToCache() async throws {
        let store = makeStore()
        try store.addPlant(name: "Basil", toleranceCelsius: 5)
        try store.replaceForecastCache(with: [night(-1.0)])

        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .failure(ForecastError.badResponse(statusCode: 500)))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        guard case .cache = viewModel.dataSource else {
            Issue.record("Expected cache fallback, got \(viewModel.dataSource)")
            return
        }
        #expect(viewModel.tonightMinC == -1.0)
        #expect(viewModel.verdicts.first?.risk == .hardFreeze)
    }

    @Test func networkFailureWithEmptyCacheReportsError() async {
        let viewModel = GardenViewModel(
            store: makeStore(),
            forecastService: MockForecastService(result: .failure(ForecastError.badURL))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        #expect(viewModel.dataSource == .none)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.verdicts.isEmpty)
    }

    @Test func refetchReplacesStaleCacheInsteadOfAppending() async throws {
        let store = makeStore()
        try store.replaceForecastCache(with: [night(9), night(8, daysFromNow: 1), night(7, daysFromNow: 2)])
        try store.replaceForecastCache(with: [night(1)])

        let cached = try store.cachedForecast()
        #expect(cached.count == 1)
        #expect(cached.first?.minTempC == 1)
    }

    @Test func plantsPersistAndRoundTrip() throws {
        let store = makeStore()
        try store.addPlant(name: "Echinacea", toleranceCelsius: -20)

        let plants = try store.plants()
        #expect(plants.count == 1)
        #expect(plants.first?.name == "Echinacea")
        #expect(plants.first?.toleranceCelsius == -20)
    }
}
