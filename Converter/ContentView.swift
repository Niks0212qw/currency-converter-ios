import SwiftUI

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

    var localizationKey: String {
        switch self {
        case .cbr:
            return "source_cbr"
        case .exchangeRate:
            return "source_exchange_rate"
        }
    }
}

class CurrencyCalculatorModel: ObservableObject {
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
    
    // Словарь для хранения курсов валют из ЦБ РФ
    @Published var cbrRates: [String: Double] = [:]
    // Словарь для хранения курсов валют из ExchangeRate API
    @Published var exchangeRates: [String: Double] = [:]
    @Published var activeRateSource: RateSource = .exchangeRate
    
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
    
    init() {
        self.backupRatesRUB = CurrencyCalculatorModel.makeRUBBackup(from: backupRatesUSD)
        
        let defaultFrom = availableCurrencies.first(where: { $0.code == "USD" }) ?? availableCurrencies[1]
        let defaultTo = availableCurrencies.first(where: { $0.code == "RUB" }) ?? availableCurrencies[0]
        
        let savedFromCode = defaults.string(forKey: fromCurrencyCodeKey)
        let savedToCode = defaults.string(forKey: toCurrencyCodeKey)
        
        self.fromCurrency = availableCurrencies.first(where: { $0.code == savedFromCode }) ?? defaultFrom
        self.toCurrency = availableCurrencies.first(where: { $0.code == savedToCode }) ?? defaultTo
        if let savedSource = defaults.string(forKey: rateSourceKey), let source = RateSource(rawValue: savedSource) {
            self.activeRateSource = source
        }
        
        if self.fromCurrency.code == self.toCurrency.code {
            self.toCurrency = defaultTo.code == self.fromCurrency.code
                ? (availableCurrencies.first(where: { $0.code != self.fromCurrency.code }) ?? defaultTo)
                : defaultTo
        }
        
        // Используем резервные курсы при инициализации
        self.exchangeRates = backupRatesUSD
        self.cbrRates = backupRatesRUB
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

    var availableRateSources: [RateSource] {
        hasRublePair ? [.cbr, .exchangeRate] : [.exchangeRate]
    }

    func setRateSource(_ source: RateSource) {
        guard availableRateSources.contains(source) else { return }
        activeRateSource = source
        persistSelectedCurrencies()
        updateConversionRate()
    }

    private var hasRublePair: Bool {
        fromCurrency.code == "RUB" || toCurrency.code == "RUB"
    }

    private var effectiveRateSource: RateSource {
        availableRateSources.contains(activeRateSource) ? activeRateSource : .exchangeRate
    }

    func syncRateSourceAvailability() {
        let available = availableRateSources
        if !available.contains(activeRateSource) {
            activeRateSource = .exchangeRate
        }
        persistSelectedCurrencies()
    }
    
    private func scheduleAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 12 * 60 * 60, repeats: true) { [weak self] _ in
            self?.fetchAllExchangeRates()
        }
    }
    
    // Функция для получения курсов из обоих источников с использованием DispatchGroup
    func fetchAllExchangeRates() {
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
        }
    }
    
    // Функция для получения курсов из Центробанка России с completion closure
    private func fetchCBRRates(completion: @escaping () -> Void) {
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else {
            completion()
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { completion(); return }
            
            DispatchQueue.main.async {
                guard error == nil, let data = data else {
                    print("CBR request error: \(String(describing: error))")
                    completion()
                    return
                }
                
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    print("CBR request HTTP error: \(http.statusCode)")
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
                    self.updateLastUpdated()
                    print("CBR rates updated successfully.")
                } catch {
                    print("Error decoding CBR data: \(error)")
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
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { completion(); return }
            
            DispatchQueue.main.async {
                guard error == nil, let data = data else {
                    print("ExchangeRate request error: \(String(describing: error))")
                    completion()
                    return
                }
                
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    print("ExchangeRate HTTP error: \(http.statusCode)")
                    completion()
                    return
                }
                
                do {
                    let ratesResponse = try JSONDecoder().decode(ExchangeRatesResponse.self, from: data)
                    
                    guard ratesResponse.result == "success" else {
                        print("ExchangeRate API error: \(ratesResponse.result)")
                        completion()
                        return
                    }
                    self.exchangeRates = ratesResponse.rates
                    self.updateLastUpdated()
                    print("ExchangeRate rates updated successfully.")
                } catch {
                    print("Error decoding ExchangeRate data: \(error)")
                }
                completion()
            }
        }.resume()
    }
    
    // Обновление метки последнего обновления
    private func updateLastUpdated(date: Date? = nil) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy, HH:mm"
        
        if let date = date {
            lastUpdated = dateFormatter.string(from: date)
        } else {
            lastUpdated = dateFormatter.string(from: Date())
        }
    }
    
    func updateConversionRate() {
        let source = effectiveRateSource
        let ratesSource = source == .cbr ? cbrRates : exchangeRates
        let fallbackSource = source == .cbr ? backupRatesRUB : backupRatesUSD

        let fromRate = ratesSource[fromCurrency.code] ?? fallbackSource[fromCurrency.code] ?? 1.0
        let toRate = ratesSource[toCurrency.code] ?? fallbackSource[toCurrency.code] ?? 1.0

        if source == .cbr {
            conversionRate = toRate == 0 ? 0 : fromRate / toRate
        } else {
            conversionRate = fromRate == 0 ? 0 : toRate / fromRate
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        formatter.minimumFractionDigits = 4
        
        if let formatted = formatter.string(from: NSNumber(value: conversionRate)) {
            calculationHistory = "1 \(fromCurrency.code) = \(formatted) \(toCurrency.code)"
        }
        
        convert()
    }
    
    func swapCurrencies() {
        let temp = fromCurrency
        fromCurrency = toCurrency
        toCurrency = temp
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
            displayValue = "0."
            isPerformingOperation = false
        } else if !displayValue.contains(".") {
            displayValue += "."
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
        if let currentValue = Double(displayValue.replacingOccurrences(of: ",", with: ".")) {
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
            if let currentValue = Double(displayValue.replacingOccurrences(of: ",", with: ".")) {
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

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed

        configuration.label
            .font(.system(size: 34, weight: .medium, design: .rounded))
            .foregroundStyle(foregroundColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isWide ? .leading : .center)
            .padding(.leading, isWide ? 28 : 0)
            .background {
                if isWide {
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
            .offset(y: pressed ? 1.8 : 0)
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

struct LiquidCurrencyCard: View {
    var currency: Currency
    var amount: String
    var isPrimary: Bool
    var scale: CGFloat = 1
    private let baseHeightScale: CGFloat = 0.915

    private var heightScale: CGFloat {
        baseHeightScale * scale
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
                        .font(.caption2)
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
                    .font(.system(size: (isPrimary ? 93 : 82) * heightScale, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.98))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
            }
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

    var body: some View {
        NavigationStack {
            ZStack {
                liquidBackground

                VStack(spacing: mainSectionSpacing) {
                    currencySection
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

    private func currencyLink(for selection: Binding<Currency>, amount: String, isPrimary: Bool) -> some View {
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
                scale: upperBlockScale
            )
        }
        .buttonStyle(.plain)
    }

    private var calculatorSection: some View {
        GeometryReader { geometry in
            let spacing = max(5.8, min(9.6, geometry.size.width * 0.021))
            let availableWidth = geometry.size.width
            let buttonSize = (availableWidth - spacing * 3) / 4

            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    textButton("C", tone: .utility, width: buttonSize, height: buttonSize) {
                        model.clear()
                    }

                    imageButton("delete.left", tone: .utility, width: buttonSize, height: buttonSize) {
                        model.deleteLastDigit()
                    }

                    textButton("%", tone: .utility, width: buttonSize, height: buttonSize) {
                        model.performOperation(.percent)
                    }

                    imageButton(
                        "divide",
                        tone: .operation,
                        width: buttonSize,
                        height: buttonSize,
                        isActive: model.pendingOperation == .divide
                    ) {
                        model.performOperation(.divide)
                    }
                }

                HStack(spacing: spacing) {
                    textButton("7", width: buttonSize, height: buttonSize) { model.appendDigit("7") }
                    textButton("8", width: buttonSize, height: buttonSize) { model.appendDigit("8") }
                    textButton("9", width: buttonSize, height: buttonSize) { model.appendDigit("9") }

                    imageButton(
                        "multiply",
                        tone: .operation,
                        width: buttonSize,
                        height: buttonSize,
                        isActive: model.pendingOperation == .multiply
                    ) {
                        model.performOperation(.multiply)
                    }
                }

                HStack(spacing: spacing) {
                    textButton("4", width: buttonSize, height: buttonSize) { model.appendDigit("4") }
                    textButton("5", width: buttonSize, height: buttonSize) { model.appendDigit("5") }
                    textButton("6", width: buttonSize, height: buttonSize) { model.appendDigit("6") }

                    imageButton(
                        "minus",
                        tone: .operation,
                        width: buttonSize,
                        height: buttonSize,
                        isActive: model.pendingOperation == .subtract
                    ) {
                        model.performOperation(.subtract)
                    }
                }

                HStack(spacing: spacing) {
                    textButton("1", width: buttonSize, height: buttonSize) { model.appendDigit("1") }
                    textButton("2", width: buttonSize, height: buttonSize) { model.appendDigit("2") }
                    textButton("3", width: buttonSize, height: buttonSize) { model.appendDigit("3") }

                    imageButton(
                        "plus",
                        tone: .operation,
                        width: buttonSize,
                        height: buttonSize,
                        isActive: model.pendingOperation == .add
                    ) {
                        model.performOperation(.add)
                    }
                }

                HStack(spacing: spacing) {
                    textButton("0", width: buttonSize * 2 + spacing, height: buttonSize, isWide: true) {
                        model.appendDigit("0")
                    }

                    textButton(".", width: buttonSize, height: buttonSize) {
                        model.appendDecimal()
                    }

                    textButton("=", tone: .operation, width: buttonSize, height: buttonSize) {
                        model.performEquals()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(minHeight: calculatorMinHeight, maxHeight: .infinity)
        .padding(.top, calculatorTopPadding)
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
                        model.setRateSource(source)
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
                    .foregroundStyle(.white.opacity(0.82))

                Text(model.calculationHistory)
                    .font(.title3.weight(.regular))
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

    @ViewBuilder
    private func textButton(
        _ title: String,
        tone: CalculatorButtonTone = .digit,
        width: CGFloat,
        height: CGFloat,
        isWide: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 34, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: isWide ? .leading : .center)
                .padding(.leading, isWide ? 28 : 0)
        }
        .buttonStyle(LiquidCalculatorButtonStyle(tone: tone, isWide: isWide))
        .frame(width: width, height: height)
    }

    @ViewBuilder
    private func imageButton(
        _ systemName: String,
        tone: CalculatorButtonTone = .digit,
        width: CGFloat,
        height: CGFloat,
        isWide: Bool = false,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 28, weight: .medium, design: .rounded))
        }
        .buttonStyle(LiquidCalculatorButtonStyle(tone: tone, isWide: isWide, isActive: isActive))
        .frame(width: width, height: height)
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var contentColumnMaxWidth: CGFloat {
        isPad ? 620 : .infinity
    }

    private var estimatedContentWidth: CGFloat {
        let screenWidth = UIScreen.main.bounds.width
        let cappedWidth = isPad ? min(620, screenWidth) : screenWidth
        return max(320, cappedWidth - 32)
    }

    private var isCompactPhone: Bool {
        !isPad && UIScreen.main.bounds.height < 760
    }

    private var isTallPhone: Bool {
        !isPad && UIScreen.main.bounds.height > 900
    }

    private var topContentPadding: CGFloat {
        if isPad { return 18 }
        if isCompactPhone { return 11 }
        if isTallPhone { return 15 }
        return 13
    }

    private var bottomContentPadding: CGFloat {
        0
    }

    private var mainSectionSpacing: CGFloat {
        if isCompactPhone { return 3 }
        if isTallPhone { return 5 }
        return 4
    }
    
    private var currencySectionSpacing: CGFloat {
        let base = isCompactPhone ? -17.6 : -19.8
        return base * upperBlockScale
    }

    private var swapButtonDiameter: CGFloat {
        let base: CGFloat = isCompactPhone ? 48 : 50
        return base * upperBlockScale
    }

    private var upperBlockScale: CGFloat {
        calculatorButtonScale
    }

    private var calculatorButtonScale: CGFloat {
        let contentWidth = estimatedContentWidth
        let spacing = max(5.8, min(9.6, contentWidth * 0.021))
        let button = (contentWidth - spacing * 3) / 4

        let baselineContentWidth: CGFloat = 358
        let baselineSpacing = max(5.8, min(9.6, baselineContentWidth * 0.021))
        let baselineButton = (baselineContentWidth - baselineSpacing * 3) / 4

        let ratio = button / baselineButton
        return max(1, min(1.7, ratio))
    }

    private var calculatorMinHeight: CGFloat {
        let contentWidth = estimatedContentWidth
        let spacing = max(5.8, min(9.6, contentWidth * 0.021))
        let button = (contentWidth - spacing * 3) / 4
        let requiredHeight = button * 5 + spacing * 4
        if isPad { return requiredHeight }
        if isCompactPhone { return requiredHeight - 10 }
        if isTallPhone { return requiredHeight + 6 }
        return requiredHeight
    }
    
    private var footerIconDiameter: CGFloat {
        isCompactPhone ? 36 : 38
    }
    
    private var footerVerticalPadding: CGFloat {
        isCompactPhone ? 5.5 : 6.5
    }

    private var footerSourceControlWidth: CGFloat {
        if isPad { return 150 }
        return isCompactPhone ? 124 : 132
    }

    private var footerVerticalOffset: CGFloat {
        isCompactPhone ? 4.5 : 6
    }

    private var calculatorTopPadding: CGFloat {
        isCompactPhone ? 6 : 7.5
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
