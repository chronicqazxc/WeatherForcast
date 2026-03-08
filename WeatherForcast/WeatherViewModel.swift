//
//  WeatherViewModel.swift
//  WeatherForcast
//
//  Created by WayneHsiao on 2026/03/08.
//

import Foundation
import SwiftUI
import Combine
import os   // For os_log

// MARK: - Remote data structures

/// Returned by the geocoding endpoint
struct GeocodingResponse: Codable {
    let results: [SearchResult]?
}

struct SearchResult: Codable {
    let latitude: Double
    let longitude: Double
    let name: String
}

/// Returned by the forecast endpoint
struct ForecastResponse: Codable {
    struct HourlyData: Codable {
        let time: [String]
        let temperature_2m: [Double]
        let weathercode: [Int]
    }
    let elevation: Double?
    let hourly: HourlyData
}

// MARK: - Local forecast model

/// Local representation of the hourly data the UI works with.
/// The three arrays must always have the same count, so we guard against that.
struct WeatherHourForecast {
    let time: [String]
    let temperature: [Double]
    let weatherCode: [Int]

    init(time: [String], temperature: [Double], weatherCode: [Int]) {
        self.time = time
        self.temperature = temperature
        self.weatherCode = weatherCode

        // Sanity: API guarantees all arrays are the same length; fail fast if that contract is broken.
        precondition(
            time.count == temperature.count && temperature.count == weatherCode.count,
            "Forecast arrays must have the same length"
        )
    }
}

// MARK: - View‑Model

/// ObservableObject that owns all the UI state and drives the network calls.
/// Marked as @MainActor so that all published properties are changed on the UI thread.
@MainActor
final class WeatherViewModel: ObservableObject {
    // MARK: Published state --------------------------

    @Published var city: String = ""
    @Published var selectedHourIndex: Int = 0

    /// Holds the forecast data. Setting it automatically resets the selected hour.
    @Published var hourlyForecast: WeatherHourForecast? {
        didSet { selectedHourIndex = 0 }
    }

    @Published var isSearching: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var temperature: Double?
    @Published var weatherCode: Int?

    // MARK: Private helpers --------------------------

    /// Current coordinates (set after geocoding)
    private var latitude: Double = 0
    private var longitude: Double = 0

    // MARK: Public API --------------------------------

    /// Initiates a geocoding request for the city name.
    func searchCity(_ cityName: String) {
        guard !cityName.isEmpty else { return }
        isSearching = true
        errorMessage = nil

        // <‑‑‑ API REQUEST LOG BEGIN ‑‑‑>
        os_log("Searching city: %{public}s", log: OSLog.default, type: .info, cityName)

        let urlStr = "https://geocoding-api.open-meteo.com/v1/search?name=\(cityName)&count=1&language=en&format=json"
        guard let url = URL(string: urlStr) else {
            isSearching = false
            return
        }

        Task {
            do {
                // <‑‑‑ API RESPONSE LOG BEGIN ‑‑‑>
                let (data, _) = try await URLSession.shared.data(from: url)
                if let jsonString = String(data: data, encoding: .utf8) {
                    os_log("Geocoding response: %{public}s", log: OSLog.default, type: .debug, jsonString)
                }

                let geoResponse = try JSONDecoder().decode(GeocodingResponse.self, from: data)

                guard let first = geoResponse.results?.first else {
                    errorMessage = "City not found"
                    isSearching = false
                    return
                }

                latitude = first.latitude
                longitude = first.longitude
                city = first.name

                // Now fetch the hourly forecast
                await fetchForecast(latitude: latitude, longitude: longitude)
                isSearching = false
            } catch {
                errorMessage = error.localizedDescription
                os_log("Geocoding error: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
                isSearching = false
            }
        }
    }

    /// Fetches the hourly forecast for the cached coordinates.
    private func fetchForecast(latitude: Double, longitude: Double) async {
        isLoading = true
        errorMessage = nil

        // <‑‑‑ API REQUEST LOG BEGIN ‑‑‑>
        os_log("Fetching forecast for lat:%{public}.4f lon:%{public}.4f", log: OSLog.default, type: .info, latitude, longitude)

        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&hourly=temperature_2m,weathercode&timezone=auto"
        guard let url = URL(string: urlStr) else {
            isLoading = false
            return
        }

        do {
            // <‑‑‑ API RESPONSE LOG BEGIN ‑‑‑>
            let (data, _) = try await URLSession.shared.data(from: url)
            if let jsonString = String(data: data, encoding: .utf8) {
                os_log("Forecast response: %{public}s", log: OSLog.default, type: .debug, jsonString)
            }

            let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: data)

            // Convert the API struct into our local model
            let forecast = WeatherHourForecast(
                time: forecastResponse.hourly.time,
                temperature: forecastResponse.hourly.temperature_2m,
                weatherCode: forecastResponse.hourly.weathercode
            )
            hourlyForecast = forecast

            // Point the selector at the “now” entry – if it isn’t present we default to the first hour
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
            formatter.timeZone = TimeZone.current
            let nowString = formatter.string(from: Date())

            if let idx = forecast.time.firstIndex(of: nowString) {
                selectedHourIndex = idx
            } else {
                selectedHourIndex = 0
            }

            updateTemperatureAndCode(index: selectedHourIndex)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            os_log("Forecast error: %{public}s", log: OSLog.default, type: .error, error.localizedDescription)
            isLoading = false
        }
    }

    // MARK: Selection helpers -----------------------

    /// Moves the selection forward/backward, wrapping as needed.
    func changeTimeSelection(delta: Int) {
        guard let forecast = hourlyForecast else { return }
        let count = forecast.time.count
        guard count > 0 else { return }
        let newIndex = (selectedHourIndex + delta).bounded(to: 0...count - 1)
        selectedHourIndex = newIndex
        updateTemperatureAndCode(index: newIndex)
    }

    /// Updates the temperature / weatherCode for the current index.
    func updateTemperatureAndCode(index: Int) {
        guard let forecast = hourlyForecast,
              forecast.time.indices.contains(index),
              forecast.temperature.indices.contains(index),
              forecast.weatherCode.indices.contains(index)
        else {
            temperature = nil
            weatherCode = nil
            return
        }

        temperature = forecast.temperature[index]
        weatherCode = forecast.weatherCode[index]
    }

    // MARK: UI helpers ------------------------------

    /// Maps Open‑Meteo codes to SF Symbols.
    func getWeatherIcon(code: Int) -> String {
        switch code {
        case 0, 800:
            return "sun.max.fill"          // Clear
        case 1:
            return "cloud.sun.fill"        // Partly cloudy
        case 2:
            return "cloud.fill"            // Cloudy
        case 3, 61:
            return "cloud.rain.fill"       // Light rain / drizzle
        case 200..<300:
            return "cloud.bolt.rain.fill"
        case 300..<600:
            return "cloud.rain.fill"
        case 600..<700:
            return "snow"
        case 700..<800:
            return "cloud.fog.fill"
        case 801..<900:
            return "cloud.sun.fill"
        default:
            return "questionmark.circle.fill"
        }
    }

    /// Human‑readable description for a code.
    func getWeatherDescription(code: Int) -> String {
        switch code {
        case 0, 800:
            return "Clear"
        case 1:
            return "Partly Cloudy"
        case 2:
            return "Cloudy"
        case 3:
            return "Light Rain"
        case 61:
            return "Drizzle"
        case 200..<300:
            return "Thunderstorm"
        case 300..<600:
            return "Rainy"
        case 600..<700:
            return "Snowy"
        case 700..<800:
            return "Foggy"
        case 801..<900:
            return "Partly Cloudy"
        default:
            os_log("Received unknown weather code: %{public}d", log: OSLog.default, type: .debug, code)
            return "Unknown Weather"
        }
    }
}
