import SwiftUI
import StoreKit
import UIKit
import os

// Структура для декодирования ответа API Центрального Банка России
struct CBRResponse: Decodable {
    let Date: String
    let PreviousDate: String
    let PreviousURL: String
    let Timestamp: String
    let Valute: [String: CBRCurrency]
    
    struct CBRCurrency: Decodable {
        let ID: String
        let NumCode: String
        let CharCode: String
        let Nominal: Int
        let Name: String
        let Value: Double
        let Previous: Double
    }
}

// Структура для декодирования ответа ExchangeRate API
struct ExchangeRatesResponse: Codable {
    let result: String
    let base_code: String
    let time_last_update_unix: Int
    let rates: [String: Double]
}

struct Currency: Identifiable, Hashable {
    var id = UUID()
    var code: String
    var name: String
    var flagName: String
    
    // Вычисляемое свойство для получения эмодзи-флага
    var flagEmoji: String {
        switch code {
        case "RUB": return "🇷🇺"
        case "USD": return "🇺🇸"
        case "EUR": return "🇪🇺"
        case "TRY": return "🇹🇷"
        case "KZT": return "🇰🇿"
        case "CNY": return "🇨🇳"
        case "AED": return "🇦🇪"
        case "UZS": return "🇺🇿"
        case "BYN": return "🇧🇾"
        case "THB": return "🇹🇭"
        case "UAH": return "🇺🇦"
        case "GBP": return "🇬🇧"
        case "JPY": return "🇯🇵"
        case "AMD": return "🇦🇲"
        case "GEL": return "🇬🇪"
        case "AUD": return "🇦🇺"
        case "CAD": return "🇨🇦"
        case "CHF": return "🇨🇭"
        case "KRW": return "🇰🇷"
        case "NZD": return "🇳🇿"
        case "SEK": return "🇸🇪"
        case "NOK": return "🇳🇴"
        case "DKK": return "🇩🇰"
        case "PLN": return "🇵🇱"
        case "AZN": return "🇦🇿"
        case "DZD": return "🇩🇿"
        case "BRL": return "🇧🇷"
        case "INR": return "🇮🇳"
        case "KGS": return "🇰🇬"
        case "TJS": return "🇹🇯"
        case "RSD": return "🇷🇸"
        case "CZK": return "🇨🇿"
        case "RON": return "🇷🇴"
        case "MDL": return "🇲🇩"
        case "EGP": return "🇪🇬"
        case "QAR": return "🇶🇦"
        case "CUP": return "🇨🇺"
        default: return "🏳️"
        }
    }
}

// Перечисление для операций калькулятора
enum CalculatorOperation {
    case none
    case add
    case subtract
    case multiply
    case divide
    case percent
    
    var symbol: String {
        switch self {
        case .none: return ""
        case .add: return "+"
        case .subtract: return "-"
        case .multiply: return "×"
        case .divide: return "÷"
        case .percent: return "%"
        }
    }
}

enum RateSource: String, CaseIterable, Hashable {
    case cbr
    case exchangeRate
    case custom

    var localizationKey: String {
        switch self {
        case .cbr:
            return "source_cbr"
        case .exchangeRate:
            return "source_exchange_rate"
        case .custom:
            return "source_custom"
        }
    }
}

class CurrencyCalculatorModel: ObservableObject {
    private static let ratesLogger = Logger(subsystem: "com.nikitakrivonosov.ConverteriOS", category: "Rates")

    @Published var displayValue: String = "0"
    @Published var fromCurrency: Currency {
        didSet {
            persistSelectedCurrencies()
            syncRateSourceAvailability()
        }
    }
    @Published var toCurrency: Currency {
        didSet {
            persistSelectedCurrencies()
            syncRateSourceAvailability()
        }
    }
    @Published var calculationHistory: String = ""
    @Published var conversionRate: Double = 0.012
    @Published var lastUpdated: String = ""
    @Published var isUsingFallbackRate: Bool = true
    @Published var isLoading: Bool = false
    @Published var convertedValue: String = "0"
    @Published var showFromCurrencyPicker = false
    @Published var showToCurrencyPicker = false
    
    // Новые переменные для функционала калькулятора
    @Published var pendingOperation: CalculatorOperation = .none
    @Published var storedValue: Double = 0.0
    @Published var isPerformingOperation: Bool = false
    @Published var showCalculatorHistory: Bool = false
    @Published var calculatorHistory: String = ""
    @Published var showReviewPrompt: Bool = false
    
    // Словарь для хранения курсов валют из ЦБ РФ
    @Published var cbrRates: [String: Double] = [:]
    // Словарь для хранения курсов валют из ExchangeRate API
    @Published var exchangeRates: [String: Double] = [:]
    @Published var activeRateSource: RateSource = .exchangeRate
    @Published private(set) var customRates: [String: Double] = [:]
    
    let availableCurrencies: [Currency] = [
        Currency(code: "RUB", name: AppL10n.currencyName("RUB"), flagName: "russia"),
        Currency(code: "USD", name: AppL10n.currencyName("USD"), flagName: "usa"),
        Currency(code: "EUR", name: AppL10n.currencyName("EUR"), flagName: "europe"),
        Currency(code: "TRY", name: AppL10n.currencyName("TRY"), flagName: "turkey"),
        Currency(code: "KZT", name: AppL10n.currencyName("KZT"), flagName: "kazakhstan"),
        Currency(code: "CNY", name: AppL10n.currencyName("CNY"), flagName: "china"),
        Currency(code: "AED", name: AppL10n.currencyName("AED"), flagName: "uae"),
        Currency(code: "UZS", name: AppL10n.currencyName("UZS"), flagName: "uzbekistan"),
        Currency(code: "BYN", name: AppL10n.currencyName("BYN"), flagName: "belarus"),
        Currency(code: "THB", name: AppL10n.currencyName("THB"), flagName: "thailand"),
        Currency(code: "UAH", name: AppL10n.currencyName("UAH"), flagName: "ukraine"),
        Currency(code: "GBP", name: AppL10n.currencyName("GBP"), flagName: "uk"),
        Currency(code: "JPY", name: AppL10n.currencyName("JPY"), flagName: "japan"),
        Currency(code: "AMD", name: AppL10n.currencyName("AMD"), flagName: "armenia"),
        Currency(code: "GEL", name: AppL10n.currencyName("GEL"), flagName: "georgia"),
        Currency(code: "AUD", name: AppL10n.currencyName("AUD"), flagName: "australia"),
        Currency(code: "CAD", name: AppL10n.currencyName("CAD"), flagName: "canada"),
        Currency(code: "CHF", name: AppL10n.currencyName("CHF"), flagName: "switzerland"),
        Currency(code: "KRW", name: AppL10n.currencyName("KRW"), flagName: "south_korea"),
        Currency(code: "NZD", name: AppL10n.currencyName("NZD"), flagName: "new_zealand"),
        Currency(code: "SEK", name: AppL10n.currencyName("SEK"), flagName: "sweden"),
        Currency(code: "NOK", name: AppL10n.currencyName("NOK"), flagName: "norway"),
        Currency(code: "DKK", name: AppL10n.currencyName("DKK"), flagName: "denmark"),
        Currency(code: "PLN", name: AppL10n.currencyName("PLN"), flagName: "poland"),
        Currency(code: "AZN", name: AppL10n.currencyName("AZN"), flagName: "azerbaijan"),
        Currency(code: "DZD", name: AppL10n.currencyName("DZD"), flagName: "algeria"),
        Currency(code: "BRL", name: AppL10n.currencyName("BRL"), flagName: "brazil"),
        Currency(code: "INR", name: AppL10n.currencyName("INR"), flagName: "india"),
        Currency(code: "KGS", name: AppL10n.currencyName("KGS"), flagName: "kyrgyzstan"),
        Currency(code: "TJS", name: AppL10n.currencyName("TJS"), flagName: "tajikistan"),
        Currency(code: "RSD", name: AppL10n.currencyName("RSD"), flagName: "serbia"),
        Currency(code: "CZK", name: AppL10n.currencyName("CZK"), flagName: "czech_republic"),
        Currency(code: "RON", name: AppL10n.currencyName("RON"), flagName: "romania"),
        Currency(code: "MDL", name: AppL10n.currencyName("MDL"), flagName: "moldova"),
        Currency(code: "EGP", name: AppL10n.currencyName("EGP"), flagName: "egypt"),
        Currency(code: "QAR", name: AppL10n.currencyName("QAR"), flagName: "qatar"),
        Currency(code: "CUP", name: AppL10n.currencyName("CUP"), flagName: "cuba")
    ]
    
    // Резервные курсы на случай проблем с API (база USD)
    private let backupRatesUSD: [String: Double] = [
        "USD": 1.0,
        "EUR": 0.92,
        "RUB": 85.49,
        "GBP": 0.78,
        "JPY": 149.8,
        "CNY": 7.18,
        "TRY": 32.5,
        "KZT": 450.2,
        "AED": 3.67,
        "UZS": 12450.0,
        "BYN": 3.25,
        "THB": 35.8,
        "UAH": 39.5,
        "AMD": 395.0,
        "GEL": 2.72,
        "AUD": 1.54,
        "CAD": 1.37,
        "CHF": 0.88,
        "KRW": 1345.0,
        "NZD": 1.67,
        "SEK": 10.6,
        "NOK": 10.8,
        "DKK": 6.92,
        "PLN": 3.96,
        "AZN": 1.70,
        "DZD": 134.0,
        "BRL": 5.45,
        "INR": 86.5,
        "KGS": 87.0,
        "TJS": 10.9,
        "RSD": 107.5,
        "CZK": 23.6,
        "RON": 4.60,
        "MDL": 17.8,
        "EGP": 49.2,
        "QAR": 3.64,
        "CUP": 24.0
    ]
    // Резервные курсы в RUB-базе (1 единица валюты = X RUB)
    private let backupRatesRUB: [String: Double]
    private var refreshTimer: Timer?
    private let defaults = UserDefaults.standard
    private let fromCurrencyCodeKey = "CurrencyCalculator.selectedFromCurrencyCode"
    private let toCurrencyCodeKey = "CurrencyCalculator.selectedToCurrencyCode"
    private let rateSourceKey = "CurrencyCalculator.selectedRateSource"
    private let customRatesKey = "CurrencyCalculator.customRates"
    private let installDateKey = "CurrencyCalculator.installDate"
    private let reviewSuccessfulActionsKey = "CurrencyCalculator.review.successfulActions"
    private let reviewLastActionDateKey = "CurrencyCalculator.review.lastActionDate"
    private let reviewLastPromptDateKey = "CurrencyCalculator.review.lastPromptDate"
    private let reviewLastDeferredDateKey = "CurrencyCalculator.review.lastDeferredDate"
    private let reviewLastPromptVersionKey = "CurrencyCalculator.review.lastPromptVersion"

    private let minimumInstallAge: TimeInterval = 7 * 24 * 60 * 60
    private let minimumSuccessfulActionsForPrompt = 12
    private let reviewPromptCooldown: TimeInterval = 120 * 24 * 60 * 60
    private let reviewDeferCooldown: TimeInterval = 30 * 24 * 60 * 60
    private let successfulActionThrottle: TimeInterval = 30
    private let rateURLSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForRequest = 15
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    private var cbrLastUpdatedDate: Date?
    private var exchangeRateLastUpdatedDate: Date?
    private var customRateLastUpdatedDate: Date?
    
    init() {
         self.backupRatesRUB = CurrencyCalculatorModel.makeRUBBackup(from: backupRatesUSD)
        
        let defaultFrom = availableCurrencies.first(where: { $0.code == "USD" }) ?? availableCurrencies[1]
        let defaultTo = availableCurrencies.first(where: { $0.code == "RUB" }) ?? availableCurrencies[0]
        
        let savedFromCode = defaults.string(forKey: fromCurrencyCodeKey)
        let savedToCode = defaults.string(forKey: toCurrencyCodeKey)
        
        // Загружаем источник курсов ДО установки валют,
        // т.к. didSet на fromCurrency/toCurrency вызывает persistSelectedCurrencies(),
        // которая перезаписала бы сохранённый источник дефолтным .exchangeRate
        if let savedSource = defaults.string(forKey: rateSourceKey), let source = RateSource(rawValue: savedSource) {
            self.activeRateSource = source
        }

        if let savedCustomRates = defaults.dictionary(forKey: customRatesKey) {
            self.customRates = savedCustomRates.compactMapValues { value in
                if let number = value as? NSNumber {
                    return number.doubleValue
                }
                return value as? Double
            }
        }
        
        self.fromCurrency = availableCurrencies.first(where: { $0.code == savedFromCode }) ?? defaultFrom
        self.toCurrency = availableCurrencies.first(where: { $0.code == savedToCode }) ?? defaultTo
        
        if self.fromCurrency.code == self.toCurrency.code {
            self.toCurrency = defaultTo.code == self.fromCurrency.code
                ? (availableCurrencies.first(where: { $0.code != self.fromCurrency.code }) ?? defaultTo)
                : defaultTo
        }

        ensureInstallDate()
        
        self.lastUpdated = AppL10n.text("rates_using_backup")
        syncRateSourceAvailability()
        persistSelectedCurrencies()
        updateConversionRate()
        
        // Загружаем актуальные курсы из обоих источников
        fetchAllExchangeRates()
        scheduleAutoRefresh()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    private static func makeRUBBackup(from usdRates: [String: Double]) -> [String: Double] {
        let rubPerUSD = usdRates["RUB"] ?? 1.0
        var rubRates: [String: Double] = ["RUB": 1.0]
        for (code, usdRate) in usdRates where code != "RUB" {
            guard usdRate != 0 else { continue }
            rubRates[code] = rubPerUSD / usdRate
        }
        return rubRates
    }
    
    private func persistSelectedCurrencies() {
        defaults.set(fromCurrency.code, forKey: fromCurrencyCodeKey)
        defaults.set(toCurrency.code, forKey: toCurrencyCodeKey)
        defaults.set(activeRateSource.rawValue, forKey: rateSourceKey)
        defaults.synchronize()
    }

    private func persistCustomRates() {
        defaults.set(customRates, forKey: customRatesKey)
        defaults.synchronize()
    }

    private func ensureInstallDate() {
        if defaults.object(forKey: installDateKey) == nil {
            defaults.set(Date(), forKey: installDateKey)
        }
    }

    var availableRateSources: [RateSource] {
        hasRublePair ? [.cbr, .exchangeRate, .custom] : [.exchangeRate, .custom]
    }

    func setRateSource(_ source: RateSource) {
        guard availableRateSources.contains(source) else { return }
        guard source != .custom || customRateForCurrentPair != nil else { return }
        activeRateSource = source
        persistSelectedCurrencies()
        updateConversionRate()
    }

    private var hasRublePair: Bool {
        fromCurrency.code == "RUB" || toCurrency.code == "RUB"
    }

    private var effectiveRateSource: RateSource {
        guard availableRateSources.contains(activeRateSource) else { return .exchangeRate }
        guard activeRateSource != .custom || customRateForCurrentPair != nil else { return .exchangeRate }
        return activeRateSource
    }

    func syncRateSourceAvailability() {
        let available = availableRateSources
        if !available.contains(activeRateSource) {
            activeRateSource = .exchangeRate
        } else if activeRateSource == .custom && customRateForCurrentPair == nil {
            activeRateSource = .exchangeRate
        }
        persistSelectedCurrencies()
    }

    private var currentPairKey: String {
        "\(fromCurrency.code)_\(toCurrency.code)"
    }

    private var inversePairKey: String {
        "\(toCurrency.code)_\(fromCurrency.code)"
    }

    private var customRateForCurrentPair: Double? {
        if let directRate = customRates[currentPairKey] {
            return directRate
        }

        guard let inverseRate = customRates[inversePairKey], inverseRate != 0 else {
            return nil
        }

        return 1 / inverseRate
    }

    func customRateDraftText() -> String {
        guard let rate = customRateForCurrentPair else { return "" }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 8
        return formatter.string(from: NSNumber(value: rate)) ?? ""
    }

    func saveCustomRate(_ input: String) -> Bool {
        guard let rate = parseCustomRate(input) else { return false }

        customRates[currentPairKey] = rate
        persistCustomRates()
        activeRateSource = .custom
        customRateLastUpdatedDate = Date()
        persistSelectedCurrencies()
        updateConversionRate()
        return true
    }

    private func parseCustomRate(_ input: String) -> Double? {
        let normalized = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00a0}", with: "")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ",", with: ".")

        guard let rate = Double(normalized), rate.isFinite, rate > 0 else {
            return nil
        }

        return rate
    }
    
    private func scheduleAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 12 * 60 * 60, repeats: true) { [weak self] _ in
            self?.fetchAllExchangeRates()
        }
    }
    
    // Функция для получения курсов из обоих источников с использованием DispatchGroup
    func fetchAllExchangeRates() {
        Self.ratesLogger.info("Starting exchange rate refresh")
        isLoading = true
        let group = DispatchGroup()
        
        group.enter()
        fetchCBRRates {
            group.leave()
        }
        
        group.enter()
        fetchExchangeRateAPI {
            group.leave()
        }
        
        group.notify(queue: .main) {
            self.updateConversionRate()
            self.isLoading = false
            Self.ratesLogger.info("Finished exchange rate refresh. Source: \(self.activeRateSource.rawValue, privacy: .public), fallback: \(self.isUsingFallbackRate, privacy: .public), rate: \(self.conversionRate, privacy: .public)")
        }
    }
    
    // Функция для получения курсов из Центробанка России с completion closure
    private func fetchCBRRates(completion: @escaping () -> Void) {
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else {
            completion()
            return
        }
        
        rateURLSession.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { completion(); return }
            
            DispatchQueue.main.async {
                guard error == nil, let data = data else {
                    Self.ratesLogger.error("CBR request failed: \(String(describing: error), privacy: .public)")
                    completion()
                    return
                }
                
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    Self.ratesLogger.error("CBR HTTP error: \(http.statusCode, privacy: .public)")
                    completion()
                    return
                }
                
                do {
                    let cbrResponse = try JSONDecoder().decode(CBRResponse.self, from: data)
                    var rates: [String: Double] = ["RUB": 1.0]
                    // Один цикл для обработки курсов из ЦБР
                    for (code, currencyData) in cbrResponse.Valute {
                        let rateInRub = currencyData.Value / Double(currencyData.Nominal)
                        rates[code] = rateInRub
                    }
                    
                    self.cbrRates = rates
                    self.cbrLastUpdatedDate = self.parseCBRDate(cbrResponse.Date) ?? Date()
                    Self.ratesLogger.info("CBR rates updated. USD/RUB: \(rates["USD"] ?? 0, privacy: .public), date: \(cbrResponse.Date, privacy: .public)")
                } catch {
                    Self.ratesLogger.error("CBR decode failed: \(String(describing: error), privacy: .public)")
                }
                completion()
            }
        }.resume()
    }
    
    // Функция для получения курсов из ExchangeRate API с completion closure
    private func fetchExchangeRateAPI(completion: @escaping () -> Void) {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            completion()
            return
        }
        
        rateURLSession.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { completion(); return }
            
            DispatchQueue.main.async {
                guard error == nil, let data = data else {
                    Self.ratesLogger.error("ExchangeRate request failed: \(String(describing: error), privacy: .public)")
                    completion()
                    return
                }
                
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    Self.ratesLogger.error("ExchangeRate HTTP error: \(http.statusCode, privacy: .public)")
                    completion()
                    return
                }
                
                do {
                    let ratesResponse = try JSONDecoder().decode(ExchangeRatesResponse.self, from: data)
                    
                    guard ratesResponse.result == "success" else {
                        Self.ratesLogger.error("ExchangeRate API returned result: \(ratesResponse.result, privacy: .public)")
                        completion()
                        return
                    }
                    self.exchangeRates = ratesResponse.rates
                    self.exchangeRateLastUpdatedDate = Date(timeIntervalSince1970: TimeInterval(ratesResponse.time_last_update_unix))
                    Self.ratesLogger.info("ExchangeRate rates updated. USD/RUB: \(ratesResponse.rates["RUB"] ?? 0, privacy: .public), updateUnix: \(ratesResponse.time_last_update_unix, privacy: .public)")
                } catch {
                    Self.ratesLogger.error("ExchangeRate decode failed: \(String(describing: error), privacy: .public)")
                }
                completion()
            }
        }.resume()
    }
    
    private func parseCBRDate(_ value: String) -> Date? {
        ISO8601DateFormatter().date(from: value)
    }

    private func formattedUpdateDate(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return dateFormatter.string(from: date)
    }

    private func updateRateStatus(source: RateSource, isFallback: Bool) {
        isUsingFallbackRate = isFallback

        guard !isFallback else {
            lastUpdated = AppL10n.text("rates_using_backup")
            return
        }

        switch source {
        case .cbr:
            lastUpdated = cbrLastUpdatedDate.map(formattedUpdateDate) ?? AppL10n.text("rates_updated")
        case .exchangeRate:
            lastUpdated = exchangeRateLastUpdatedDate.map(formattedUpdateDate) ?? AppL10n.text("rates_updated")
        case .custom:
            lastUpdated = customRateLastUpdatedDate.map(formattedUpdateDate) ?? AppL10n.text("source_custom")
        }
    }
    
    func updateConversionRate() {
        let source = effectiveRateSource
        let isFallback: Bool

        switch source {
        case .cbr:
            let liveFromRate = cbrRates[fromCurrency.code]
            let liveToRate = cbrRates[toCurrency.code]
            isFallback = liveFromRate == nil || liveToRate == nil
            let fromRate = liveFromRate ?? backupRatesRUB[fromCurrency.code] ?? 1.0
            let toRate = liveToRate ?? backupRatesRUB[toCurrency.code] ?? 1.0
            conversionRate = toRate == 0 ? 0 : fromRate / toRate
        case .exchangeRate:
            let liveFromRate = exchangeRates[fromCurrency.code]
            let liveToRate = exchangeRates[toCurrency.code]
            isFallback = liveFromRate == nil || liveToRate == nil
            let fromRate = liveFromRate ?? backupRatesUSD[fromCurrency.code] ?? 1.0
            let toRate = liveToRate ?? backupRatesUSD[toCurrency.code] ?? 1.0
            conversionRate = fromRate == 0 ? 0 : toRate / fromRate
        case .custom:
            isFallback = false
            conversionRate = customRateForCurrentPair ?? 0
        }

        updateRateStatus(source: source, isFallback: isFallback)
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 4
        
        if let formatted = formatter.string(from: NSNumber(value: conversionRate)) {
            calculationHistory = "1 \(fromCurrency.code) = \(formatted) \(toCurrency.code)"
        }
        
        convert()
    }

    private func registerSuccessfulActionIfNeeded() {
        guard displayValue != "0",
              !displayValue.isEmpty,
              convertedValue != AppL10n.text("error_generic") else { return }

        let now = Date()
        if let lastActionDate = defaults.object(forKey: reviewLastActionDateKey) as? Date,
           now.timeIntervalSince(lastActionDate) < successfulActionThrottle {
            return
        }

        defaults.set(now, forKey: reviewLastActionDateKey)
        let newCount = defaults.integer(forKey: reviewSuccessfulActionsKey) + 1
        defaults.set(newCount, forKey: reviewSuccessfulActionsKey)
        evaluateReviewPromptEligibility(now: now, successfulActionsCount: newCount)
    }

    private func evaluateReviewPromptEligibility(now: Date = Date(), successfulActionsCount: Int? = nil) {
        guard !showReviewPrompt else { return }

        let installDate = (defaults.object(forKey: installDateKey) as? Date) ?? now
        guard now.timeIntervalSince(installDate) >= minimumInstallAge else { return }

        let actions = successfulActionsCount ?? defaults.integer(forKey: reviewSuccessfulActionsKey)
        guard actions >= minimumSuccessfulActionsForPrompt else { return }

        if let deferredAt = defaults.object(forKey: reviewLastDeferredDateKey) as? Date,
           now.timeIntervalSince(deferredAt) < reviewDeferCooldown {
            return
        }

        if let promptedAt = defaults.object(forKey: reviewLastPromptDateKey) as? Date,
           now.timeIntervalSince(promptedAt) < reviewPromptCooldown {
            return
        }

        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        let lastPromptVersion = defaults.string(forKey: reviewLastPromptVersionKey)
        guard lastPromptVersion != currentVersion else { return }

        showReviewPrompt = true
    }

    func deferReviewPrompt() {
        defaults.set(Date(), forKey: reviewLastDeferredDateKey)
        showReviewPrompt = false
    }

    func submitReviewPrompt() {
        let now = Date()
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        defaults.set(now, forKey: reviewLastPromptDateKey)
        defaults.set(currentVersion, forKey: reviewLastPromptVersionKey)
        defaults.set(0, forKey: reviewSuccessfulActionsKey)
        showReviewPrompt = false
        requestReviewIfPossible()
    }

    private func requestReviewIfPossible() {
        DispatchQueue.main.async {
            guard let scene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene else {
                return
            }
            SKStoreReviewController.requestReview(in: scene)
        }
    }
    
    func swapCurrencies() {
        let savedSource = activeRateSource
        let temp = fromCurrency
        fromCurrency = toCurrency
        toCurrency = temp
        // Восстанавливаем источник, если он всё ещё доступен после свопа
        if availableRateSources.contains(savedSource) {
            activeRateSource = savedSource
            persistSelectedCurrencies()
        }
        updateConversionRate()
    }
    
    // MARK: - Методы калькулятора
    
    func appendDigit(_ digit: String) {
        if isPerformingOperation {
            displayValue = digit
            isPerformingOperation = false
        } else if displayValue == "0" {
            displayValue = digit
        } else {
            displayValue += digit
        }
        convert()
    }
    
    func appendDecimal() {
        if isPerformingOperation {
            displayValue = "0,"
            isPerformingOperation = false
        } else if !displayValue.contains(",") {
            displayValue += ","
        }
        convert()
    }
    
    func clear() {
        displayValue = "0"
        pendingOperation = .none
        storedValue = 0.0
        calculatorHistory = ""
        convert()
    }
    
    func deleteLastDigit() {
        if displayValue.count > 1 {
            displayValue.removeLast()
        } else {
            displayValue = "0"
        }
        convert()
    }
    
    func performOperation(_ operation: CalculatorOperation) {
        if let currentValue = Double(displayValue.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) {
            if operation == .percent {
                let percentResult = currentValue / 100.0
                displayValue = formatDisplayValue(percentResult)
                convert()
                return
            }
            
            if pendingOperation != .none {
                let result = calculateResult(storedValue, currentValue)
                displayValue = formatDisplayValue(result)
                storedValue = result
            } else {
                storedValue = currentValue
            }
            
            pendingOperation = operation
            isPerformingOperation = true
            calculatorHistory = "\(formatDisplayValue(storedValue)) \(operation.symbol)"
        }
        
        convert()
    }
    
    func performEquals() {
        if pendingOperation != .none {
            if let currentValue = Double(displayValue.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: ",", with: ".")) {
                let result = calculateResult(storedValue, currentValue)
                calculatorHistory = "\(formatDisplayValue(storedValue)) \(pendingOperation.symbol) \(formatDisplayValue(currentValue)) = \(formatDisplayValue(result))"
                displayValue = formatDisplayValue(result)
                pendingOperation = .none
                isPerformingOperation = true
                convert()
            }
        }
    }
    
    private func calculateResult(_ firstValue: Double, _ secondValue: Double) -> Double {
        switch pendingOperation {
        case .add:
            return firstValue + secondValue
        case .subtract:
            return firstValue - secondValue
        case .multiply:
            return firstValue * secondValue
        case .divide:
            return secondValue != 0 ? firstValue / secondValue : 0
        case .percent:
            return firstValue * (secondValue / 100.0)
        case .none:
            return secondValue
        }
    }
    
    private func formatDisplayValue(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = " "
        formatter.maximumFractionDigits = 10

        if value.truncatingRemainder(dividingBy: 1) == 0 {
            formatter.maximumFractionDigits = 0
        }

        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
    
    func convert() {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        
        if let number = formatter.number(from: displayValue) {
            let result = number.doubleValue * conversionRate
            formatter.maximumFractionDigits = 2
            if let formattedResult = formatter.string(from: NSNumber(value: result)) {
                convertedValue = formattedResult
                registerSuccessfulActionIfNeeded()
            } else {
                convertedValue = AppL10n.text("error_generic")
            }
        } else {
            let cleanValue = displayValue
                .replacingOccurrences(of: " ", with: "")
                .replacingOccurrences(of: ",", with: ".")
            
            if let value = Double(cleanValue) {
                let result = value * conversionRate
                formatter.maximumFractionDigits = 2
                if let formattedResult = formatter.string(from: NSNumber(value: result)) {
                    convertedValue = formattedResult
                    registerSuccessfulActionIfNeeded()
                } else {
                    convertedValue = AppL10n.text("error_generic")
                }
            } else {
                convertedValue = "0"
            }
        }
    }
    
    func getRateForCurrency(_ currency: Currency) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        
        if currency.code == "RUB" {
            let rubPerUSD = cbrRates["USD"] ?? backupRatesRUB["USD"]
            if let rubPerUSD, let formattedRate = formatter.string(from: NSNumber(value: rubPerUSD)) {
                return "1 USD = \(formattedRate) RUB"
            }
            return "N/A"
        }
        
        let usdRate = exchangeRates["USD"] ?? backupRatesUSD["USD"]
        let currencyRate = exchangeRates[currency.code] ?? backupRatesUSD[currency.code]
        
        guard let usdRate, let currencyRate else { return "N/A" }
        
        let rate = currencyRate / usdRate
        if let formattedRate = formatter.string(from: NSNumber(value: rate)) {
            return "1 USD = \(formattedRate) \(currency.code)"
        }
        
        return "N/A"
    }
}

struct FlagCircleView: View {
    var currency: Currency
    var emojiSize: CGFloat = 24

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                )

            Text(currency.flagEmoji)
                .font(.system(size: emojiSize))
        }
    }
}

enum CalculatorButtonTone {
    case utility
    case digit
    case operation
}

struct LiquidCalculatorButtonStyle: ButtonStyle {
    var tone: CalculatorButtonTone
    var isWide: Bool = false
    var isActive: Bool = false
    var isOval: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(.system(size: 34, weight: .medium, design: .rounded))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isWide ? .leading : .center)
            .background {
                if isWide || isOval {
                    let shape = Capsule()
                    shape
                        .fill(buttonFill(pressed: pressed))
                        .overlay(shape.strokeBorder(Color.white.opacity(pressed ? 0.12 : 0.24), lineWidth: 1))
                } else {
                    let shape = Circle()
                    shape
                        .fill(buttonFill(pressed: pressed))
                        .overlay(shape.strokeBorder(Color.white.opacity(pressed ? 0.12 : 0.24), lineWidth: 1))
                }
            }
            .shadow(color: shadowColor(pressed: pressed), radius: pressed ? 0.5 : 1.5, x: 0, y: pressed ? 0.5 : 1)
            .scaleEffect(pressed ? 0.95 : 1)
            .offset(y: pressed ? 4 : 0)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }

    private var foregroundColor: Color {
        switch tone {
        case .utility:
            return Color.white.opacity(0.96)
        case .digit:
            return Color.white.opacity(0.94)
        case .operation:
            return isActive ? Color(red: 0.98, green: 0.47, blue: 0.08) : .white
        }
    }

    private func buttonFill(pressed: Bool) -> Color {
        switch tone {
        case .utility:
            return Color.white.opacity(pressed ? 0.18 : 0.24)
        case .digit:
            return Color.white.opacity(pressed ? 0.1 : 0.14)
        case .operation:
            if isActive {
                return Color.white.opacity(pressed ? 0.7 : 0.82)
            }
            return Color(red: 0.98, green: 0.53, blue: 0.2).opacity(pressed ? 0.88 : 1)
        }
    }

    private func shadowColor(pressed: Bool) -> Color {
        if tone == .operation && !isActive {
            return Color(red: 1.0, green: 0.54, blue: 0.15).opacity(pressed ? 0.04 : 0.08)
        }

        return Color.black.opacity(pressed ? 0.03 : 0.07)
    }
}

struct LiquidIconButtonStyle: ButtonStyle {
    var diameter: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(Color.white.opacity(pressed ? 0.1 : 0.14))
                    .overlay(
                        Circle()
                            .strokeBorder(Color.white.opacity(pressed ? 0.1 : 0.18), lineWidth: 1)
                    )
            }
            .shadow(color: Color.black.opacity(pressed ? 0.03 : 0.07), radius: pressed ? 0.5 : 1.5, x: 0, y: pressed ? 0.5 : 1)
            .scaleEffect(pressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.12), value: pressed)
    }
}

struct CustomRateEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: CurrencyCalculatorModel
    @State private var rateText = ""
    @State private var showsValidationError = false

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    var body: some View {
        ZStack {
            Color(red: 0.06, green: 0.09, blue: 0.16)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: isPad ? 18 : 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(AppL10n.text("custom_rate_title"))
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)

                    Text(String(format: AppL10n.text("custom_rate_pair"), model.fromCurrency.code, model.toCurrency.code))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.68))
                }

                TextField("0", text: $rateText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(showsValidationError ? Color.red.opacity(0.75) : Color.white.opacity(0.16), lineWidth: 1)
                    )

                Text(showsValidationError ? AppL10n.text("custom_rate_error") : AppL10n.text("custom_rate_hint"))
                    .font(.footnote)
                    .foregroundStyle(showsValidationError ? Color.red.opacity(0.9) : Color.white.opacity(0.62))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 10) {
                    Button {
                        dismiss()
                    } label: {
                        Text(AppL10n.text("custom_rate_cancel"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.25))

                    Button {
                        if model.saveCustomRate(rateText) {
                            dismiss()
                        } else {
                            showsValidationError = true
                        }
                    } label: {
                        Text(AppL10n.text("custom_rate_save"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 1.0, green: 0.53, blue: 0.2))
                }
            }
            .padding(20)
            .frame(maxWidth: isPad ? 520 : .infinity)
        }
        .onAppear {
            rateText = model.customRateDraftText()
            showsValidationError = false
        }
        .presentationDetents([.height(isPad ? 330 : 300)])
        .presentationDragIndicator(.visible)
    }
}

struct LiquidCurrencyCard: View {
    var currency: Currency
    var amount: String
    var isPrimary: Bool
    var scale: CGFloat = 1
    var isIPhoneAir: Bool = false
    private let baseHeightScale: CGFloat = 0.915

    private var heightScale: CGFloat {
        baseHeightScale * scale
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var isIPhoneSE: Bool {
        guard !isPad else { return false }
        let screenBounds = UIScreen.main.bounds
        let shortestSide = min(screenBounds.width, screenBounds.height)
        let longestSide = max(screenBounds.width, screenBounds.height)
        return shortestSide <= 375 && longestSide <= 667
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8 * heightScale) {
            HStack(spacing: 15 * heightScale) {
                FlagCircleView(currency: currency, emojiSize: 29 * heightScale)
                    .frame(width: 50 * heightScale, height: 50 * heightScale)

                VStack(alignment: .leading, spacing: 1) {
                    Text(currency.code)
                        .font(.system(size: 24 * heightScale, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))

                    Text(currency.name)
                        .font(isPad
                            ? .system(size: 14 * heightScale, weight: .regular)
                            : .caption2)
                        .foregroundStyle(.white.opacity(0.65))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.45))
            }

            HStack {
                Spacer()

                Text(amount)
                    .font(.system(size: 93 * heightScale * 0.5 * (isIPhoneSE ? 1.15 : 1.0), weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.98))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
            .frame(height: 93 * heightScale / (isPad ? 1.0 : 1.5) * (isPad ? 1.0 : 0.751) * (isIPhoneSE ? 0.857 : 1.0) * (isIPhoneAir ? 0.93 : 1.0))
        }
        .padding(15 * heightScale)
        .background(
            Color.white.opacity(0.1),
            in: RoundedRectangle(cornerRadius: 35 * heightScale, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 35 * heightScale, style: .continuous)
                .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 1.5 * heightScale, x: 0, y: 1 * heightScale)
    }
}

struct ContentView: View {
    @StateObject private var model = CurrencyCalculatorModel()
    @State private var showCustomRateEditor = false

    var body: some View {
        Group {
            if isPad {
                iPadBody
            } else {
                iPhoneBody
            }
        }
        .alert(AppL10n.text("review_prompt_title"), isPresented: $model.showReviewPrompt) {
            Button(AppL10n.text("review_prompt_later"), role: .cancel) {
                model.deferReviewPrompt()
            }
            Button(AppL10n.text("review_prompt_rate")) {
                model.submitReviewPrompt()
            }
        } message: {
            Text(AppL10n.text("review_prompt_message"))
        }
        .sheet(isPresented: $showCustomRateEditor) {
            CustomRateEditorView(model: model)
        }
    }

    private var iPhoneBody: some View {
        NavigationStack {
            ZStack {
                liquidBackground

                VStack(spacing: mainSectionSpacing) {
                    currencySection
                        .offset(y: currencySectionVerticalOffset)
                    calculatorSection
                        .layoutPriority(1)
                    footerSection
                }
                .padding(.horizontal, 16)
                .padding(.top, topContentPadding)
                .padding(.bottom, bottomContentPadding)
                .frame(maxWidth: contentColumnMaxWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var liquidBackground: some View {
        Color(red: 0.06, green: 0.09, blue: 0.16)
            .ignoresSafeArea()
    }

    private var currencySection: some View {
        VStack(spacing: currencySectionSpacing) {
            currencyLink(for: $model.fromCurrency, amount: model.displayValue, isPrimary: true)

            HStack {
                Spacer()

                Button {
                    model.swapCurrencies()
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.28))
                }
                .buttonStyle(LiquidIconButtonStyle(diameter: swapButtonDiameter))

                Spacer()
            }
            .zIndex(1)

            currencyLink(for: $model.toCurrency, amount: model.convertedValue, isPrimary: false)
        }
    }

    private func currencyLink(for selection: Binding<Currency>, amount: String, isPrimary: Bool, scale: CGFloat? = nil) -> some View {
        NavigationLink(
            destination: CurrencyPickerView(
                selectedCurrency: selection,
                availableCurrencies: model.availableCurrencies,
                title: AppL10n.text("currencies_title"),
                onCurrencySelected: { newCurrency in
                    selection.wrappedValue = newCurrency
                    model.updateConversionRate()
                }
            )
            .navigationBarTitle(AppL10n.text("currencies_title"), displayMode: .inline)
            .environmentObject(model)
        ) {
            LiquidCurrencyCard(
                currency: selection.wrappedValue,
                amount: amount,
                isPrimary: isPrimary,
                scale: scale ?? upperBlockScale,
                isIPhoneAir: isIPhoneAir
            )
        }
        .buttonStyle(.plain)
    }

    private var calculatorSection: some View {
        GeometryReader { geometry in
            let spacing = isIPhoneSEFormFactor
                ? max(3.5, min(6.5, geometry.size.width * 0.018))
                : max(5.8, min(9.6, geometry.size.width * 0.021))
            let useOvalButtons = isIPhoneSEFormFactor
            let availableWidth = geometry.size.width
            let buttonSize = (availableWidth - spacing * 3) / 4
            let buttonHeight = buttonSize * phoneCalculatorButtonHeightRatio
            let fontSize = max(isIPhoneSEFormFactor ? 26 : 30, buttonHeight * 0.42)
            let iconSize = max(isIPhoneSEFormFactor ? 22 : 24, buttonHeight * 0.34)

            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    textButton("C", tone: .utility, width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) {
                        model.clear()
                    }

                    imageButton("delete.left", tone: .utility, width: buttonSize, height: buttonHeight, iconSize: iconSize, isOval: useOvalButtons) {
                        model.deleteLastDigit()
                    }

                    textButton("%", tone: .utility, width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) {
                        model.performOperation(.percent)
                    }

                    imageButton(
                        "divide",
                        tone: .operation,
                        width: buttonSize,
                        height: buttonHeight,
                        iconSize: iconSize,
                        isActive: model.pendingOperation == .divide,
                        isOval: useOvalButtons
                    ) {
                        model.performOperation(.divide)
                    }
                }

                HStack(spacing: spacing) {
                    textButton("7", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) { model.appendDigit("7") }
                    textButton("8", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) { model.appendDigit("8") }
                    textButton("9", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) { model.appendDigit("9") }

                    imageButton(
                        "multiply",
                        tone: .operation,
                        width: buttonSize,
                        height: buttonHeight,
                        iconSize: iconSize,
                        isActive: model.pendingOperation == .multiply,
                        isOval: useOvalButtons
                    ) {
                        model.performOperation(.multiply)
                    }
                }

                HStack(spacing: spacing) {
                    textButton("4", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) { model.appendDigit("4") }
                    textButton("5", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) { model.appendDigit("5") }
                    textButton("6", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) { model.appendDigit("6") }

                    imageButton(
                        "minus",
                        tone: .operation,
                        width: buttonSize,
                        height: buttonHeight,
                        iconSize: iconSize,
                        isActive: model.pendingOperation == .subtract,
                        isOval: useOvalButtons
                    ) {
                        model.performOperation(.subtract)
                    }
                }

                HStack(spacing: spacing) {
                    textButton("1", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) { model.appendDigit("1") }
                    textButton("2", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) { model.appendDigit("2") }
                    textButton("3", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) { model.appendDigit("3") }

                    imageButton(
                        "plus",
                        tone: .operation,
                        width: buttonSize,
                        height: buttonHeight,
                        iconSize: iconSize,
                        isActive: model.pendingOperation == .add,
                        isOval: useOvalButtons
                    ) {
                        model.performOperation(.add)
                    }
                }

                HStack(spacing: spacing) {
                    textButton("0", width: buttonSize * 2 + spacing, height: buttonHeight, fontSize: fontSize, isWide: true, isOval: useOvalButtons) {
                        model.appendDigit("0")
                    }

                    textButton(",", width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) {
                        model.appendDecimal()
                    }

                    textButton("=", tone: .operation, width: buttonSize, height: buttonHeight, fontSize: fontSize, isOval: useOvalButtons) {
                        model.performEquals()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(minHeight: calculatorMinHeight, maxHeight: .infinity)
        .padding(.top, calculatorTopPadding)
        .offset(y: calculatorVerticalOffset)
    }

    private var footerSection: some View {
        HStack(spacing: 12) {
            Button {
                model.fetchAllExchangeRates()
            } label: {
                ZStack {
                    if model.isLoading {
                        ProgressView()
                            .tint(.white.opacity(0.9))
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
            }
            .buttonStyle(LiquidIconButtonStyle(diameter: footerIconDiameter))

            Menu {
                ForEach(model.availableRateSources, id: \.self) { source in
                    Button {
                        if source == .custom {
                            showCustomRateEditor = true
                        } else {
                            model.setRateSource(source)
                        }
                    } label: {
                        if source == model.activeRateSource {
                            Label(AppL10n.text(source.localizationKey), systemImage: "checkmark")
                        } else {
                            Text(AppL10n.text(source.localizationKey))
                        }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(AppL10n.text(model.activeRateSource.localizationKey))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.65))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.1), in: Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
                .frame(width: footerSourceControlWidth, alignment: .leading)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(model.lastUpdated)
                    .font(.caption)
                    .foregroundStyle(model.isUsingFallbackRate ? Color(red: 1.0, green: 0.74, blue: 0.28) : .white.opacity(0.82))

                Text(model.calculationHistory)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, footerVerticalPadding)
        .background(
            Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 30, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 1.5, x: 0, y: 1)
        .offset(y: footerVerticalOffset)
    }

    // MARK: - iPad Layout

    private var iPadBody: some View {
        NavigationStack {
            ZStack {
                liquidBackground
                GeometryReader { geo in
                    let colW: CGFloat = min(geo.size.width * 0.80, 860)
                    let contentW: CGFloat = max(320, colW - 32)
                    let calcSpacing: CGFloat = max(5.8, min(9.6, contentW * 0.021))
                    let buttonW: CGFloat = (contentW - calcSpacing * 3) / 4
                    let buttonH: CGFloat = buttonW * 0.65
                    let calcH: CGFloat = 7.5 + buttonH * 5 + calcSpacing * 4
                    let topPad: CGFloat = 18
                    let footerH: CGFloat = 54
                    let sectionGap: CGFloat = 4
                    let availForCards: CGFloat = geo.size.height - topPad - calcH - footerH - sectionGap * 2
                    let cardScale: CGFloat = max(0.7, min(2.2, availForCards / 331.5))

                    VStack(spacing: sectionGap) {
                        iPadCurrencySection(scale: cardScale)
                        iPadCalculatorSection(contentW: contentW)
                            .frame(height: calcH)
                        footerSection
                            .frame(height: footerH)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, topPad)
                    .frame(maxWidth: colW)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func iPadCurrencySection(scale: CGFloat) -> some View {
        VStack(spacing: -19.8 * scale) {
            currencyLink(
                for: $model.fromCurrency,
                amount: model.displayValue,
                isPrimary: true,
                scale: scale
            )

            HStack {
                Spacer()
                Button { model.swapCurrencies() } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(Color(red: 1.0, green: 0.74, blue: 0.28))
                }
                .buttonStyle(LiquidIconButtonStyle(diameter: scale * 50))
                Spacer()
            }
            .zIndex(1)

            currencyLink(
                for: $model.toCurrency,
                amount: model.convertedValue,
                isPrimary: false,
                scale: scale
            )
        }
    }

    @ViewBuilder
    private func iPadCalculatorSection(contentW: CGFloat) -> some View {
        let spacing: CGFloat = max(5.8, min(9.6, contentW * 0.021))
        let buttonW: CGFloat = (contentW - spacing * 3) / 4
        let buttonH: CGFloat = buttonW * 0.65
        let fontSize: CGFloat = max(22, buttonH * 0.32)
        let iconSize: CGFloat = max(18, buttonH * 0.26)

        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                textButton("C", tone: .utility, width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.clear() }
                imageButton("delete.left", tone: .utility, width: buttonW, height: buttonH, iconSize: iconSize, isOval: true) { model.deleteLastDigit() }
                textButton("%", tone: .utility, width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.performOperation(.percent) }
                imageButton("divide", tone: .operation, width: buttonW, height: buttonH, iconSize: iconSize, isActive: model.pendingOperation == .divide, isOval: true) { model.performOperation(.divide) }
            }
            HStack(spacing: spacing) {
                textButton("7", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDigit("7") }
                textButton("8", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDigit("8") }
                textButton("9", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDigit("9") }
                imageButton("multiply", tone: .operation, width: buttonW, height: buttonH, iconSize: iconSize, isActive: model.pendingOperation == .multiply, isOval: true) { model.performOperation(.multiply) }
            }
            HStack(spacing: spacing) {
                textButton("4", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDigit("4") }
                textButton("5", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDigit("5") }
                textButton("6", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDigit("6") }
                imageButton("minus", tone: .operation, width: buttonW, height: buttonH, iconSize: iconSize, isActive: model.pendingOperation == .subtract, isOval: true) { model.performOperation(.subtract) }
            }
            HStack(spacing: spacing) {
                textButton("1", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDigit("1") }
                textButton("2", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDigit("2") }
                textButton("3", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDigit("3") }
                imageButton("plus", tone: .operation, width: buttonW, height: buttonH, iconSize: iconSize, isActive: model.pendingOperation == .add, isOval: true) { model.performOperation(.add) }
            }
            HStack(spacing: spacing) {
                textButton(
                    "0",
                    width: buttonW * 2 + spacing,
                    height: buttonH,
                    fontSize: fontSize,
                    isWide: true,
                    wideLeadingPadding: buttonW * 0.44
                ) { model.appendDigit("0") }
                textButton(",", width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.appendDecimal() }
                textButton("=", tone: .operation, width: buttonW, height: buttonH, fontSize: fontSize, isOval: true) { model.performEquals() }
            }
        }
        .padding(.top, 7.5)
    }

    @ViewBuilder
    private func textButton(
        _ title: String,
        tone: CalculatorButtonTone = .digit,
        width: CGFloat,
        height: CGFloat,
        fontSize: CGFloat = 34,
        isWide: Bool = false,
        isOval: Bool = false,
        wideLeadingPadding: CGFloat = 34,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: fontSize, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isWide ? .leading : .center)
                .padding(.leading, isWide ? wideLeadingPadding : 0)
        }
        .buttonStyle(LiquidCalculatorButtonStyle(tone: tone, isWide: isWide, isOval: isOval))
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private func imageButton(
        _ systemName: String,
        tone: CalculatorButtonTone = .digit,
        width: CGFloat,
        height: CGFloat,
        iconSize: CGFloat = 28,
        isWide: Bool = false,
        isActive: Bool = false,
        isOval: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: iconSize, weight: .medium, design: .rounded))
        }
        .buttonStyle(LiquidCalculatorButtonStyle(tone: tone, isWide: isWide, isActive: isActive, isOval: isOval))
        .frame(width: width, height: height)
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var contentColumnMaxWidth: CGFloat {
        if isPad {
            let screenWidth = UIScreen.main.bounds.width
            // Адаптивная ширина колонки: iPad mini (~460pt) → iPad Pro 13" (580pt)
            return min(screenWidth * 0.60, 580)
        }
        return .infinity
    }

    private var estimatedContentWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let cappedWidth = isPad ? min(contentColumnMaxWidth, screenWidth) : screenWidth
        return max(320, cappedWidth - 32)
    }

    private var isCompactPhone: Bool {
        !isPad && UIScreen.main.bounds.height < 760
    }

    private var isTallPhone: Bool {
        !isPad && UIScreen.main.bounds.height > 900
    }

    private var isIPhoneSEFormFactor: Bool {
        guard !isPad else { return false }
        #if targetEnvironment(simulator)
        let simulatorName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
        if simulatorName.localizedCaseInsensitiveContains("iphone se") {
            return true
        }
        #endif
        let screenBounds = UIScreen.main.bounds
        let shortestSide = min(screenBounds.width, screenBounds.height)
        let longestSide = max(screenBounds.width, screenBounds.height)
        return shortestSide <= 375 && longestSide <= 667
    }

    private static let iPhoneAirModelIdentifiers: Set<String> = [
        "iPhone18,4"
    ]

    private var deviceModelIdentifier: String {
        #if targetEnvironment(simulator)
        return ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] ?? ""
        #else
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) { machinePtr in
            machinePtr.withMemoryRebound(to: CChar.self, capacity: 1) { cStringPtr in
                String(cString: cStringPtr)
            }
        }
        #endif
    }

    private var isIPhoneAir: Bool {
        guard !isPad else { return false }
        #if targetEnvironment(simulator)
        let simulatorName = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ?? ""
        if simulatorName.localizedCaseInsensitiveContains("iphone air") {
            return true
        }
        #endif
        return Self.iPhoneAirModelIdentifiers.contains(deviceModelIdentifier)
    }

    private var topContentPadding: CGFloat {
        let basePadding: CGFloat
        if isPad {
            basePadding = 18
        } else if isIPhoneSEFormFactor {
            basePadding = 6
        } else if isCompactPhone {
            basePadding = 11
        } else if isTallPhone {
            basePadding = 15
        } else {
            basePadding = 13
        }
        return isIPhoneAir ? basePadding * 1.15 : basePadding
    }

    private var bottomContentPadding: CGFloat {
        0
    }

    private var mainSectionSpacing: CGFloat {
        if isIPhoneSEFormFactor { return 2 }
        if isCompactPhone { return 3 }
        if isTallPhone { return 5 }
        return 4
    }
    
    private var currencySectionSpacing: CGFloat {
        let base: CGFloat
        if isIPhoneSEFormFactor {
            base = -19.2
        } else if isCompactPhone {
            base = -17.6
        } else {
            base = -19.8
        }
        return base * upperBlockScale
    }

    private var swapButtonDiameter: CGFloat {
        let base: CGFloat
        if isIPhoneSEFormFactor {
            base = 46
        } else if isCompactPhone {
            base = 48
        } else {
            base = 50
        }
        return base * upperBlockScale
    }

    private var upperBlockScale: CGFloat {
        let scale = calculatorButtonScale
        if isIPhoneSEFormFactor { return scale * 0.9 }
        return scale
    }

    private var calculatorButtonScale: CGFloat {
        let contentWidth = estimatedContentWidth
        let spacing = max(5.8, min(9.6, contentWidth * 0.021))
        let button = (contentWidth - spacing * 3) / 4

        let baselineContentWidth: CGFloat = 358
        let baselineSpacing = max(5.8, min(9.6, baselineContentWidth * 0.021))
        let baselineButton = (baselineContentWidth - baselineSpacing * 3) / 4

        let ratio = button / baselineButton
        let minScale: CGFloat = isIPhoneSEFormFactor ? 0.9 : 1
        return max(minScale, min(1.7, ratio))
    }

    private var phoneCalculatorButtonHeightRatio: CGFloat {
        if isIPhoneSEFormFactor { return 0.84 }
        return 1
    }

    private var calculatorMinHeight: CGFloat {
        let contentWidth = estimatedContentWidth
        let spacing = max(5.8, min(9.6, contentWidth * 0.021))
        let button = (contentWidth - spacing * 3) / 4
        let buttonHeight = button * phoneCalculatorButtonHeightRatio
        let requiredHeight = buttonHeight * 5 + spacing * 4
        if isPad { return requiredHeight }
        if isIPhoneSEFormFactor { return requiredHeight - 14 }
        if isCompactPhone { return requiredHeight - 10 }
        if isTallPhone { return requiredHeight + 6 }
        return requiredHeight
    }
    
    private var footerIconDiameter: CGFloat {
        if isIPhoneSEFormFactor { return 34 }
        return isCompactPhone ? 36 : 38
    }
    
    private var footerVerticalPadding: CGFloat {
        if isIPhoneSEFormFactor { return 5 }
        return isCompactPhone ? 5.5 : 6.5
    }

    private var footerSourceControlWidth: CGFloat {
        if isPad { return 150 }
        if isIPhoneSEFormFactor { return 110 }
        return isCompactPhone ? 124 : 132
    }

    private var footerVerticalOffset: CGFloat {
        if isTallPhone { return -2 }
        if isIPhoneSEFormFactor { return -11 }
        return isCompactPhone ? 4.5 : 6
    }

    private var calculatorTopPadding: CGFloat {
        if isIPhoneSEFormFactor { return 3.5 }
        return isCompactPhone ? 6 : 7.5
    }

    private var calculatorVerticalOffset: CGFloat {
        if isIPhoneSEFormFactor { return -6 }
        return 0
    }

    private var currencySectionVerticalOffset: CGFloat {
        if isIPhoneAir { return 2 }
        return 0
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
