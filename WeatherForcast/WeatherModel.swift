// WeatherModel.swift
//
//  WeatherModel.swift
//  WeatherForcast
//
//  Created by WayneHsiao on 2026/03/08.
//

import Foundation

// Define the response wrapper for Open-Meteo
struct WeatherResponse: Codable {
    let current_weather: CurrentWeather?
}

// Define the specific weather details
struct CurrentWeather: Codable {
    let temperature: Double
    let weathercode: Int
}

// Helper function to convert WMO codes to readable descriptions
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
