//
//  FrostCalculatorTests.swift
//  FrostSentinelTests
//
//  Exercises the legacy Objective-C calculator through the Swift bridge —
//  which is itself part of what these tests verify.
//

import Testing
@testable import FrostSentinel

struct FrostCalculatorTests {

    private let calculator = FSFrostCalculator()

    // Tolerance 0°C plant (tender annual) against varying forecasts.

    @Test func comfortableMarginIsNoRisk() {
        #expect(calculator.risk(forForecastMinCelsius: 8, toleranceCelsius: 0) == .none)
    }

    @Test func withinWatchMarginIsWatch() {
        #expect(calculator.risk(forForecastMinCelsius: 2, toleranceCelsius: 0) == .watch)
    }

    @Test func exactlyAtToleranceIsFrost() {
        #expect(calculator.risk(forForecastMinCelsius: 0, toleranceCelsius: 0) == .frost)
    }

    @Test func slightlyBelowToleranceIsFrost() {
        #expect(calculator.risk(forForecastMinCelsius: -2, toleranceCelsius: 0) == .frost)
    }

    @Test func farBelowToleranceIsHardFreeze() {
        #expect(calculator.risk(forForecastMinCelsius: -5, toleranceCelsius: 0) == .hardFreeze)
    }

    @Test func hardyPlantShrugsOffAFrostyNight() {
        // A -15°C tolerant perennial on a -4°C night: no risk.
        #expect(calculator.risk(forForecastMinCelsius: -4, toleranceCelsius: -15) == .none)
    }

    @Test func marginIsForecastMinusTolerance() {
        #expect(calculator.margin(forForecastMinCelsius: 3, toleranceCelsius: -2) == 5)
        #expect(calculator.margin(forForecastMinCelsius: -6, toleranceCelsius: -2) == -4)
    }

    @Test func customMarginsAreRespected() {
        let strict = FSFrostCalculator(watchMarginCelsius: 6, hardFreezeMarginCelsius: 1)
        #expect(strict.risk(forForecastMinCelsius: 5, toleranceCelsius: 0) == .watch)
        #expect(strict.risk(forForecastMinCelsius: -2, toleranceCelsius: 0) == .hardFreeze)
    }

    @Test func adviceMentionsThePlantByName() {
        let advice = calculator.advice(for: .frost, plantName: "Lavender")
        #expect(advice.contains("Lavender"))
        #expect(advice.contains("Cover"))
    }
}
