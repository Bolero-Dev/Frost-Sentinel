//
//  ForecastService.swift
//  FrostSentinel
//
//  Fetches nightly minimum temperatures from the Open-Meteo REST API.
//  No API key, no account — consistent with the app's no-tracking posture.
//

import Foundation

/// One night's forecast minimum.
struct NightForecast: Equatable {
    let date: Date
    let minTempC: Double
}

/// Abstraction over the forecast source so the view model can be tested
/// without touching the network.
protocol ForecastFetching {
    func nightlyMinimums(
        latitude: Double,
        longitude: Double,
        days: Int
    ) async throws -> [NightForecast]
}

enum ForecastError: Error, Equatable {
    case badURL
    case badResponse(statusCode: Int)
    case malformedPayload
}

/// Live Open-Meteo implementation.
///
/// Endpoint shape:
/// https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..
///   &daily=temperature_2m_min&timezone=auto&forecast_days=N
struct OpenMeteoForecastService: ForecastFetching {
    var session: URLSession = .shared

    func nightlyMinimums(
        latitude: Double,
        longitude: Double,
        days: Int
    ) async throws -> [NightForecast] {
        guard let url = makeURL(latitude: latitude, longitude: longitude, days: days) else {
            throw ForecastError.badURL
        }

        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ForecastError.badResponse(statusCode: http.statusCode)
        }

        return try Self.parse(data)
    }

    func makeURL(latitude: Double, longitude: Double, days: Int) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: String(days)),
        ]
        return components?.url
    }

    // MARK: - Decoding

    /// Open-Meteo returns parallel arrays; this zips them into typed values.
    /// Static and pure so it is directly unit-testable against fixtures.
    static func parse(_ data: Data) throws -> [NightForecast] {
        let decoded: OpenMeteoResponse
        do {
            decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        } catch {
            throw ForecastError.malformedPayload
        }

        guard decoded.daily.time.count == decoded.daily.temperature2mMin.count else {
            throw ForecastError.malformedPayload
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        return try zip(decoded.daily.time, decoded.daily.temperature2mMin).map { day, minTemp in
            guard let date = formatter.date(from: day) else {
                throw ForecastError.malformedPayload
            }
            return NightForecast(date: date, minTempC: minTemp)
        }
    }
}

// MARK: - DTOs

struct OpenMeteoResponse: Decodable {
    let daily: Daily

    struct Daily: Decodable {
        let time: [String]
        let temperature2mMin: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2mMin = "temperature_2m_min"
        }
    }
}
