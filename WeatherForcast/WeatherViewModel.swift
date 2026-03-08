//
//  WeatherViewModel.swift
//  WeatherForcast
//
//  Created by WayneHsiao on 2026/03/08.
//

import Foundation
import SwiftUI
import Combine

// 1. Codable Structs for API Data
struct GeocodingResponse: Codable {
    let results: [SearchResult]?
}

struct SearchResult: Codable {
    let latitude: Double
    let longitude: Double
    let name: String
}

struct ForecastResponse: Codable {
    struct HourlyData: Codable {
        let time: [String]
        let temperature_2m: [Double]
        let weathercode: [Int]
    }
    
    let elevation: Double?
    let hourly: HourlyData
}

// 2. State Properties
class WeatherViewModel: ObservableObject {
    @Published var latitude: Double = 37.7749
    @Published var longitude: Double = -122.4194
    @Published var city: String = "San Francisco"
    @Published var hourlyForecast: ForecastResponse.HourlyData?
    @Published var selectedHourIndex: Int = 0
    @Published var temperature: Double?
    @Published var weatherCode: Int?
    @Published var isLoading = false
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    init() {
        searchCity(city)
    }

    func getWeatherDescription(code: Int) -> String {
        switch code {
        case 0: return "Clear Sky"
        case 1, 2, 3: return "Partly Cloudy"
        case 45, 48: return "Foggy"
        case 51, 53, 55, 61, 63, 65: return "Drizzle"
        case 71, 73, 75, 77: return "Snow"
        case 80, 81, 82: return "Rain"
        case 95, 96, 99: return "Thunderstorm"
        default: return "Unknown"
        }
    }

    func getWeatherIcon(code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2, 3: return "cloud.sun.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 61, 63, 65: return "cloud.drizzle.fill"
        case 71, 73, 75, 77: return "snowflake.fill"
        case 80, 81, 82: return "cloud.rain.fill"
        case 95, 96, 99: return "cloud.bolt.fill"
        default: return "cloud.fill"
        }
    }

    // --- Logic Methods ---
    
    func searchCity(_ cityName: String) {
        guard !cityName.isEmpty else { return }
        isSearching = true
        
        // Geocoding API
        let urlStr = "https://geocoding-api.open-meteo.com/v1/search?name=\(cityName)&count=1&language=en&format=json"
        
        guard let url = URL(string: urlStr) else { return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(GeocodingResponse.self, from: data)
                
                if let firstResult = response.results?.first {
                    self.latitude = firstResult.latitude
                    self.longitude = firstResult.longitude
                    self.city = firstResult.name
                    await self.fetchForecast(latitude: self.latitude, longitude: self.longitude)
                } else {
                    DispatchQueue.main.async {
                        self.errorMessage = "City not found"
                        self.isSearching = false
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isSearching = false
                }
            }
        }
    }
    
    func fetchForecast(latitude: Double, longitude: Double) {
        isLoading = true
        errorMessage = nil
        
        let urlStr = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&hourly=temperature_2m,weathercode&timezone=auto"
        
        guard let url = URL(string: urlStr) else { isLoading = false; return }
        
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONDecoder().decode(ForecastResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.hourlyForecast = response.hourly
                    
                    let now = Date()
                    let dateString = ISO8601DateFormatter().string(from: now)
                    
                    if let index = self.hourlyForecast?.time.firstIndex(of: dateString) {
                        self.selectedHourIndex = index
                        self.updateTemperatureAndCode(index: index)
                    } else {
                        self.selectedHourIndex = 0
                        self.updateTemperatureAndCode(index: 0)
                    }
                    
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    func updateTemperatureAndCode(index: Int) {
        guard let hourly = hourlyForecast else { return }
        
        if index >= 0, index < hourly.temperature_2m.count {
            self.temperature = hourly.temperature_2m[index]
            self.weatherCode = hourly.weathercode[index]
        }
    }
    
    func changeTimeSelection(delta: Int) {
        guard let hourly = hourlyForecast else { return }
        
        let newIndex = selectedHourIndex + delta
        if newIndex >= 0, newIndex < hourly.time.count {
            self.selectedHourIndex = newIndex
            updateTemperatureAndCode(index: newIndex)
        }
    }
}
