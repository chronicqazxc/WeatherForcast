//  ContentView.swift
//  WeatherForcast

import SwiftUI

/// Main view – demonstrates the date‑picker range, arrow navigation,
/// and dynamic weather data based on the selected hour.
struct ContentView: View {
    @StateObject private var viewModel = WeatherViewModel()
    @State private var inputCity: String = ""
    @State private var selectedDate = Date()

    // MARK: Formatters
    private let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        fmt.locale = Locale(identifier: "en_US")
        return fmt
    }()

    private let apiDateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm"
        fmt.timeZone = TimeZone(secondsFromGMT: 0)
        return fmt
    }()

    // MARK: Body
    var body: some View {
        VStack(spacing: 20) {
            // 0️⃣ Search bar
            searchBar

            // 1️⃣ Date picker – full forecast range
            if let forecast = viewModel.hourlyForecast,
               let dateRange = forecastRange(for: forecast) {
                datePicker(forecast: forecast, dateRange: dateRange)
            }

            // 2️⃣ Time navigation controls
            timeNavigationControls

            // 3️⃣ City name
            cityName

            // 4️⃣ Weather display
            weatherDisplay

            Spacer()
        }
        .padding(20)
        .onChange(of: viewModel.selectedHourIndex) { _ in
            updateSelectedDateFromModel()
        }
        .onAppear {
            // If no forecast is present, start with a sensible default.
            if viewModel.hourlyForecast == nil {
                // Use the city stored in UserDefaults or fall back to a hard‑coded city.
                let defaultCity = UserDefaults.standard.string(forKey: "lastCity") ?? "San Francisco"
                viewModel.searchCity(defaultCity)
            }
            // Keep the picker in sync after any data load.
            updateSelectedDateFromModel()
        }
    }

    // MARK: --- Sub‑Views

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
            TextField("Search city", text: $inputCity)
                .onSubmit {
                    if !inputCity.isEmpty {
                        viewModel.searchCity(inputCity)
                        inputCity = ""
                    }
                }
            if viewModel.isSearching { ProgressView() }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }

    private func datePicker(forecast: WeatherHourForecast, dateRange: ClosedRange<Date>) -> some View {
        DatePicker(
            "Select Date & Time",
            selection: $selectedDate,
            in: dateRange,
            displayedComponents: [.date, .hourAndMinute]
        )
        .datePickerStyle(.compact)
        .padding(.horizontal)
        .onChange(of: selectedDate) { newDate in
            updateSelectedIndexFromDate(newDate, forecast: forecast)
        }
    }

    // MARK: - Updated
    private var timeNavigationControls: some View {
        Group { // Wrap the conditional in a Group to satisfy `some View`
            if viewModel.hourlyForecast != nil {
                HStack {
                    Button { viewModel.changeTimeSelection(delta: -1) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(viewModel.selectedHourIndex <= 0)

                    Text("Current Selection")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button { viewModel.changeTimeSelection(delta: 1) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(viewModel.selectedHourIndex + 1 >= (viewModel.hourlyForecast?.time.count ?? 0))
                }
                .padding(.horizontal, 10)
            } else {
                EmptyView()
            }
        }
    }

    private var cityName: some View {
        Group {
            if !viewModel.city.isEmpty {
                Spacer()
                Text(viewModel.city)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            } else {
                EmptyView()
            }
        }
    }

    private var weatherDisplay: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Fetching weather data...")
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else if let temp = viewModel.temperature,
                      let code = viewModel.weatherCode {
                weatherComponents(temp: temp, code: code)
            } else {
                Text("No data found")
            }
        }
    }

    private func weatherComponents(temp: Double, code: Int) -> some View {
        VStack(spacing: 15) {
            // Date indicator
            if let timeStr = viewModel.hourlyForecast?.time[viewModel.selectedHourIndex],
               let dateObj = apiDateFormatter.date(from: timeStr) {
                Text(dateFormatter.string(from: dateObj))
                    .font(.headline)
                    .foregroundStyle(.blue)
            }

            // Icon
            Image(systemName: viewModel.getWeatherIcon(code: code))
                .font(.system(size: 70))
                .foregroundStyle(.blue)

            // Temperature
            Text("\(Int(temp))°C")
                .font(.system(size: 80, weight: .bold, design: .rounded))

            // Description
            Text(viewModel.getWeatherDescription(code: code))
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .transition(.opacity)
    }

    // MARK: --- Helpers

    /// Builds the closed range that covers the entire forecast period.
    private func forecastRange(for forecast: WeatherHourForecast) -> ClosedRange<Date>? {
        let dates = forecast.time.compactMap { apiDateFormatter.date(from: $0) }
        guard let min = dates.min(), let max = dates.max() else { return nil }
        return min...max
    }

    /// When the `ViewModel` changes its index, update the DatePicker’s selection.
    private func updateSelectedDateFromModel() {
        // 1️⃣ Ensure we have a forecast and the index is valid.
        guard let forecast = viewModel.hourlyForecast,
              viewModel.selectedHourIndex < forecast.time.count else {
            return
        }

        // 2️⃣ Grab the string at the selected index.
        let dateStr = forecast.time[viewModel.selectedHourIndex]

        // 3️⃣ Convert that string into a Date (optional), and set the picker.
        guard let date = apiDateFormatter.date(from: dateStr) else {
            return
        }

        selectedDate = date
    }

    /// Called when the user picks a new date from the picker.
    private func updateSelectedIndexFromDate(_ date: Date, forecast: WeatherHourForecast) {
        for (idx, timeStr) in forecast.time.enumerated() {
            guard let timeDate = apiDateFormatter.date(from: timeStr) else { continue }
            if Calendar.current.isDate(timeDate, inSameDayAs: date) &&
                Calendar.current.component(.hour, from: timeDate) == Calendar.current.component(.hour, from: date) {

                viewModel.selectedHourIndex = idx
                viewModel.updateTemperatureAndCode(index: idx)
                break
            }
        }
    }
}

#Preview {
    ContentView()
}

