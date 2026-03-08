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
    // Open-Meteo sends format: "2026-03-07T02:00"
    let apiDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
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
            if let _ = viewModel.hourlyForecast {
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
            
            // 3. City Name Display
            if !viewModel.city.isEmpty {
                Spacer()
                Text(viewModel.city)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            
            // 4. Weather Display
            if viewModel.isLoading {
                ProgressView("Fetching weather data...")
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else if let temp = viewModel.temperature, let code = viewModel.weatherCode {
                VStack(spacing: 15) {
                    // Date Indicator
                    if let selectedTimeString = viewModel.hourlyForecast?.time[viewModel.selectedHourIndex],
                       let dateObj = apiDateFormatter.date(from: selectedTimeString) {
                        Text(dateFormatter.string(from: dateObj))
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                    
                    // Main Icon
                    Image(systemName: viewModel.getWeatherIcon(code: code))
                        .font(.system(size: 70))
                        .foregroundStyle(.blue)
                    
                    // Main Temperature
                    Text("\(Int(temp))°C")
                        .font(.system(size: 80, weight: .bold, design: .rounded))
                    
                    // Weather Description
                    Text(viewModel.getWeatherDescription(code: code))
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity)
            } else {
                Text("No data found")
            }
            
            Spacer()
        }
        .padding(20)
    }
}

#Preview {
    ContentView()
}

