//
//  ForecastServiceTests.swift
//  FrostSentinelTests
//
//  Tests the Open-Meteo response parsing against fixtures — no network.
//

import Foundation
import Testing
@testable import FrostSentinel

struct ForecastServiceTests {

    private let validPayload = """
    {
      "daily": {
        "time": ["2026-07-06", "2026-07-07", "2026-07-08"],
        "temperature_2m_min": [4.2, -1.5, 0.0]
      }
    }
    """.data(using: .utf8)!

    @Test func parsesParallelArraysIntoTypedNights() throws {
        let nights = try OpenMeteoForecastService.parse(validPayload)
        #expect(nights.count == 3)
        #expect(nights[0].minTempC == 4.2)
        #expect(nights[1].minTempC == -1.5)
        #expect(nights[0].date < nights[1].date)
    }

    @Test func mismatchedArrayLengthsAreRejected() {
        let bad = """
        {"daily": {"time": ["2026-07-06", "2026-07-07"], "temperature_2m_min": [4.2]}}
        """.data(using: .utf8)!

        #expect(throws: ForecastError.malformedPayload) {
            _ = try OpenMeteoForecastService.parse(bad)
        }
    }

    @Test func garbageJSONIsRejected() {
        let garbage = "{not json".data(using: .utf8)!
        #expect(throws: ForecastError.malformedPayload) {
            _ = try OpenMeteoForecastService.parse(garbage)
        }
    }

    @Test func unparseableDateIsRejected() {
        let badDate = """
        {"daily": {"time": ["tomorrow-ish"], "temperature_2m_min": [4.2]}}
        """.data(using: .utf8)!

        #expect(throws: ForecastError.malformedPayload) {
            _ = try OpenMeteoForecastService.parse(badDate)
        }
    }

    @Test func urlIncludesCoordinatesAndDailyMinimum() throws {
        let service = OpenMeteoForecastService()
        let url = try #require(service.makeURL(latitude: 40.76, longitude: -111.89, days: 3))
        let query = try #require(url.query())

        #expect(url.host() == "api.open-meteo.com")
        #expect(query.contains("latitude=40.76"))
        #expect(query.contains("longitude=-111.89"))
        #expect(query.contains("temperature_2m_min"))
        #expect(query.contains("forecast_days=3"))
    }
}
