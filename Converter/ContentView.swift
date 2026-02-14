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

class CurrencyCalculatorModel: ObservableObject {
    @Published var displayValue: String = "0"
    @Published var fromCurrency: Currency {
        didSet { persistSelectedCurrencies() }
    }
    @Published var toCurrency: Currency {
        didSet { persistSelectedCurrencies() }
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
        Currency(code: "JPY", name: AppL10n.currencyName("JPY"), flagName: "japan")
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
        "UAH": 39.5
    ]
    // Резервные курсы в RUB-базе (1 единица валюты = X RUB)
    private let backupRatesRUB: [String: Double]
    private var refreshTimer: Timer?
    private let defaults = UserDefaults.standard
    private let fromCurrencyCodeKey = "CurrencyCalculator.selectedFromCurrencyCode"
    private let toCurrencyCodeKey = "CurrencyCalculator.selectedToCurrencyCode"
    
    init() {
        self.backupRatesRUB = CurrencyCalculatorModel.makeRUBBackup(from: backupRatesUSD)
        
        let defaultFrom = availableCurrencies.first(where: { $0.code == "USD" }) ?? availableCurrencies[1]
        let defaultTo = availableCurrencies.first(where: { $0.code == "RUB" }) ?? availableCurrencies[0]
        
        let savedFromCode = defaults.string(forKey: fromCurrencyCodeKey)
        let savedToCode = defaults.string(forKey: toCurrencyCodeKey)
        
        self.fromCurrency = availableCurrencies.first(where: { $0.code == savedFromCode }) ?? defaultFrom
        self.toCurrency = availableCurrencies.first(where: { $0.code == savedToCode }) ?? defaultTo
        
        if self.fromCurrency.code == self.toCurrency.code {
            self.toCurrency = defaultTo.code == self.fromCurrency.code
                ? (availableCurrencies.first(where: { $0.code != self.fromCurrency.code }) ?? defaultTo)
                : defaultTo
        }
        
        // Используем резервные курсы при инициализации
        self.exchangeRates = backupRatesUSD
        self.cbrRates = backupRatesRUB
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
        defaults.synchronize()
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
        // Определяем, нужно ли использовать данные ЦБ РФ
        let useCBR = fromCurrency.code == "RUB" || toCurrency.code == "RUB"
        
        // Выбираем источник курсов
        let ratesSource = useCBR ? cbrRates : exchangeRates
        let fallbackSource = useCBR ? backupRatesRUB : backupRatesUSD
        
        let fromRate = ratesSource[fromCurrency.code] ?? fallbackSource[fromCurrency.code] ?? 1.0
        let toRate = ratesSource[toCurrency.code] ?? fallbackSource[toCurrency.code] ?? 1.0

        if useCBR {
            if fromCurrency.code == "RUB" {
                conversionRate = 1.0 / toRate
            } else if toCurrency.code == "RUB" {
                conversionRate = fromRate
            } else {
                conversionRate = toRate / fromRate
            }
        } else {
            conversionRate = toRate / fromRate
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
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 60, height: 60)
            Text(currency.flagEmoji)
                .font(.system(size: 32))
        }
    }
}

struct CalculatorButtonStyle: ButtonStyle {
    var backgroundColor: Color
    var foregroundColor: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 32, weight: .medium))
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .overlay(
                Rectangle()
                    .stroke(Color.black, lineWidth: configuration.isPressed ? 3 : 0)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CurrencyView: View {
    var currency: Currency
    var amount: String
    
    var body: some View {
        HStack {
            FlagCircleView(currency: currency)
            Text(currency.code)
                .font(.title)
                .fontWeight(.medium)
                .foregroundColor(.white)
            Spacer()
            Text(amount)
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
        .padding(.horizontal)
        .padding(.vertical, 25)
    }
}

struct ContentView: View {
    @StateObject private var model = CurrencyCalculatorModel()
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    NavigationLink(destination:
                        CurrencyPickerView(
                            selectedCurrency: $model.fromCurrency,
                            availableCurrencies: model.availableCurrencies,
                            title: AppL10n.text("currencies_title"),
                            onCurrencySelected: { newCurrency in
                                model.fromCurrency = newCurrency
                                model.updateConversionRate()
                            }
                        )
                        .navigationBarTitle(AppL10n.text("currencies_title"), displayMode: .inline)
                        .environmentObject(model)
                    ) {
                        CurrencyView(currency: model.fromCurrency, amount: model.displayValue)
                            .background(Color(UIColor.darkGray).opacity(0.9))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    ZStack {
                        Rectangle()
                            .fill(Color.black)
                            .frame(height: 28)
                        
                        Button(action: {
                            model.swapCurrencies()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.black)
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray, lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    .offset(y: -12)
                    .zIndex(1)
                    
                    NavigationLink(destination:
                        CurrencyPickerView(
                            selectedCurrency: $model.toCurrency,
                            availableCurrencies: model.availableCurrencies,
                            title: AppL10n.text("currencies_title"),
                            onCurrencySelected: { newCurrency in
                                model.toCurrency = newCurrency
                                model.updateConversionRate()
                            }
                        )
                        .navigationBarTitle(AppL10n.text("currencies_title"), displayMode: .inline)
                        .environmentObject(model)
                    ) {
                        CurrencyView(currency: model.toCurrency, amount: model.convertedValue)
                            .background(Color(UIColor.darkGray).opacity(0.9))
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.top, -20)
                    
                    VStack(spacing: 0) {
                        HStack(spacing: 0) {
                            Button("C") {
                                model.clear()
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button {
                                model.deleteLastDigit()
                            } label: {
                                Image(systemName: "delete.left")
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button("%") {
                                model.performOperation(.percent)
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button {
                                model.performOperation(.divide)
                            } label: {
                                Image(systemName: "divide")
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                        }
                        
                        Divider().frame(height: 1).background(Color.black)
                        
                        HStack(spacing: 0) {
                            Button("7") {
                                model.appendDigit("7")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button("8") {
                                model.appendDigit("8")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button("9") {
                                model.appendDigit("9")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button {
                                model.performOperation(.multiply)
                            } label: {
                                Image(systemName: "multiply")
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                        }
                        
                        Divider().frame(height: 1).background(Color.black)
                        
                        HStack(spacing: 0) {
                            Button("4") {
                                model.appendDigit("4")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button("5") {
                                model.appendDigit("5")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button("6") {
                                model.appendDigit("6")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button {
                                model.performOperation(.subtract)
                            } label: {
                                Image(systemName: "minus")
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                        }
                        
                        Divider().frame(height: 1).background(Color.black)
                        
                        HStack(spacing: 0) {
                            Button("1") {
                                model.appendDigit("1")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button("2") {
                                model.appendDigit("2")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button("3") {
                                model.appendDigit("3")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button {
                                model.performOperation(.add)
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 24))
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                        }
                        
                        Divider().frame(height: 1).background(Color.black)
                        
                        HStack(spacing: 0) {
                            Button("0") {
                                model.appendDigit("0")
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            .frame(width: UIScreen.main.bounds.width / 2 - 0.5)
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button(".") {
                                model.appendDecimal()
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color(UIColor.darkGray).opacity(0.9), foregroundColor: .white))
                            
                            Divider().frame(width: 1).background(Color.black)
                            
                            Button("=") {
                                model.performEquals()
                            }
                            .buttonStyle(CalculatorButtonStyle(backgroundColor: Color.orange, foregroundColor: .white))
                        }
                    }
                    .background(Color.black)
                    
                    HStack {
                        Button {
                            model.fetchAllExchangeRates()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                        
                        Text(model.fromCurrency.code == "RUB" || model.toCurrency.code == "RUB" ? AppL10n.text("source_cbr") : AppL10n.text("source_exchange_rate"))
                            .font(.caption)
                            .foregroundColor(.yellow)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(4)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text(model.lastUpdated)
                                .font(.caption)
                                .foregroundColor(.green)
                            
                            Text(model.calculationHistory)
                                .font(.callout)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.black)
                }
                .edgesIgnoringSafeArea(.bottom)
                .navigationBarHidden(true)
            }
            .accentColor(.yellow)
            .preferredColorScheme(.dark)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
