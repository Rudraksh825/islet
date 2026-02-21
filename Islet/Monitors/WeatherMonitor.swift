import Foundation
import CoreLocation
import Combine
import os.log

private let log = OSLog(subsystem: "com.islet.app", category: "Weather")

final class WeatherMonitor: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var temperature: Double = 0
    @Published var condition: String = ""
    @Published var sfSymbol: String = "cloud"
    @Published var precipitationProbability: Int = 0
    @Published var shouldShow: Bool = false

    private let locationManager = CLLocationManager()
    private var location: CLLocationCoordinate2D?
    private var refreshTimer: AnyCancellable?
    private var showTimer: AnyCancellable?
    private let networkQueue = DispatchQueue(label: "com.islet.weather", qos: .utility)

    override init() {
        super.init()
        locationManager.delegate = self
    }

    func start() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        schedulePeriodicRefresh()
    }

    func stop() {
        locationManager.stopUpdatingLocation()
        refreshTimer?.cancel()
        showTimer?.cancel()
    }

    private func schedulePeriodicRefresh() {
        let intervalMinutes = Double(SystemConfig.shared.weatherRefreshMinutes)
        refreshTimer = Timer.publish(every: intervalMinutes * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.fetchWeather() }
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        location = loc.coordinate
        manager.stopUpdatingLocation()
        fetchWeather()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        os_log(.debug, log: log, "Location error: %{public}@", error.localizedDescription)
        // Fallback: try IP geolocation
        fetchLocationFromIP()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            fetchLocationFromIP()
        default:
            break
        }
    }

    private func fetchLocationFromIP() {
        guard let url = URL(string: "https://ipapi.co/json/") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let lat = json["latitude"] as? Double,
                  let lon = json["longitude"] as? Double else { return }
            self?.location = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            self?.fetchWeather()
        }.resume()
    }

    // MARK: - Weather fetch
    private func fetchWeather() {
        guard let loc = location else { return }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(loc.latitude)),
            URLQueryItem(name: "longitude", value: String(loc.longitude)),
            URLQueryItem(name: "current_weather", value: "true"),
            URLQueryItem(name: "hourly", value: "precipitation_probability"),
            URLQueryItem(name: "temperature_unit", value: "celsius"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]
        guard let url = components.url else { return }

        var request = URLRequest(url: url, timeoutInterval: 10)
        networkQueue.async {
            URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
                if let error = error {
                    os_log(.debug, log: log, "Weather fetch error: %{public}@", error.localizedDescription)
                    return
                }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let current = json["current_weather"] as? [String: Any],
                      let temp = current["temperature"] as? Double,
                      let code = current["weathercode"] as? Int else { return }

                let hourly = json["hourly"] as? [String: Any]
                let precipProbs = hourly?["precipitation_probability"] as? [Int]
                let precipProb = precipProbs?.first ?? 0

                DispatchQueue.main.async {
                    self?.temperature = temp
                    self?.condition = WeatherMonitor.conditionString(for: code)
                    self?.sfSymbol = WeatherMonitor.sfSymbol(for: code)
                    self?.precipitationProbability = precipProb
                    self?.triggerShow()
                }
            }.resume()
        }
    }

    private func triggerShow() {
        shouldShow = true
        showTimer?.cancel()
        showTimer = Just(())
            .delay(for: .seconds(8), scheduler: DispatchQueue.main)
            .sink { [weak self] in self?.shouldShow = false }
    }

    // MARK: - WMO Weather Code mappings
    static func conditionString(for code: Int) -> String {
        switch code {
        case 0: return "Clear Sky"
        case 1: return "Mainly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 61, 63, 65: return "Rain"
        case 71, 73, 75: return "Snow"
        case 80, 81, 82: return "Rain Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with Hail"
        default: return "Unknown"
        }
    }

    static func sfSymbol(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1: return "sun.max"
        case 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95: return "cloud.bolt.rain.fill"
        case 96, 99: return "cloud.bolt.fill"
        default: return "cloud"
        }
    }
}
