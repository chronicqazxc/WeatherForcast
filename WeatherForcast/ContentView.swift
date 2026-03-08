//
//  ContentView.swift
//  WeatherForcast
//
//  Created by WayneHsiao on 2026/03/08.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var inputCity: String = ""
    
    // Formatter for the selected time
    let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()
    
    // Formatter to parse Open-Meteo's API string into a Date
    let apiDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds, .withTimeZone]
        return formatter
    }()

    var body: some View {
        VStack(spacing: 20) {
            // 1. Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search city", text: $inputCity)
                    .onSubmit {
                        if !inputCity.isEmpty {
                            viewModel.searchCity(inputCity)
                            inputCity = ""
                        }
                    }
                if viewModel.isSearching {
                    ProgressView()
                }
            }
            .padding(8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            
            // 2. Time Navigation Controls
            if viewModel.hourlyForecast != nil {
                HStack {
                    Button(action: { viewModel.changeTimeSelection(delta: -1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(viewModel.selectedHourIndex - 1 < 0)
                    
                    // Helper text
                    Text("Current Selection")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button(action: { viewModel.changeTimeSelection(delta: 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(viewModel.selectedHourIndex + 1 >= (viewModel.hourlyForecast?.time.count ?? 0))
                }
                .padding(.horizontal, 10)
            }
            
            Spacer()
            
            // 3. Weather Display
            if viewModel.isLoading {
                ProgressView("Fetching weather data...")
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else if let temp = viewModel.temperature, let code = viewModel.weatherCode {
                VStack(spacing: 15) {
                    // --- Date Indicator ---
                    // Extract the time string from the data array and format it
                    if let selectedTimeString = viewModel.hourlyForecast?.time[viewModel.selectedHourIndex] {
                        if let dateObj = apiDateFormatter.date(from: selectedTimeString) {
                            Text(dateFormatter.string(from: dateObj))
                                .font(.headline)
                                .foregroundStyle(.blue)
                        } else {
                            Text(selectedTimeString)
                                .font(.caption)
                        }
                    }
                    
                    // Main Icon
                    Image(systemName: viewModel.getWeatherIcon(code: code))
                        .font(.system(size: 70))
                        .foregroundStyle(.blue)
                    
                    // Main Text
                    Text("\(Int(temp))°C")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                    
                    // Helper Text (Description)
                    Text(viewModel.getWeatherDescription(code: code))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else {
                Text("No data found")
            }
        }
        .padding(20)
    }
}

#Preview {
    ContentView()
}

