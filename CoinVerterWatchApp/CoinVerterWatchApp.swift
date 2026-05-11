import SwiftUI
import WidgetKit

private struct WatchCurrency: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }

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

private enum WatchCalculatorOperation {
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
        case .multiply: return "x"
        case .divide: return "/"
        case .percent: return "%"
        }
    }
}

private enum WatchRateSource: String, CaseIterable, Identifiable {
    case exchangeRate
    case cbr

    var id: String { rawValue }

    var shortTitle: String {
        switch self {
        case .exchangeRate: return "ER"
        case .cbr: return "CBR"
        }
    }

    var title: String {
        switch self {
        case .exchangeRate: return "ExchangeRate"
        case .cbr: return "CBR"
        }
    }
}

private struct WatchExchangeRatesResponse: Codable {
    let result: String
    let rates: [String: Double]
}

private struct WatchCBRResponse: Decodable {
    let Valute: [String: CBRCurrency]

    struct CBRCurrency: Decodable {
        let Nominal: Int
        let Value: Double
    }
}

@MainActor
private final class WatchConverterModel: ObservableObject {
    private static let autoRefreshInterval: TimeInterval = 12 * 60 * 60

    @Published var fromCurrency: WatchCurrency {
        didSet {
            persistSelection()
            syncSourceAvailability()
            updateConversionRate()
        }
    }

    @Published var toCurrency: WatchCurrency {
        didSet {
            persistSelection()
            syncSourceAvailability()
            updateConversionRate()
        }
    }

    @Published var displayValue = "0"
    @Published var convertedValue = "0"
    @Published var calculationHistory = ""
    @Published var pendingOperation: WatchCalculatorOperation = .none
    @Published var source: WatchRateSource = .exchangeRate
    @Published var isLoading = false

    let currencies: [WatchCurrency] = [
        WatchCurrency(code: "RUB", name: "Russian Ruble"),
        WatchCurrency(code: "USD", name: "US Dollar"),
        WatchCurrency(code: "EUR", name: "Euro"),
        WatchCurrency(code: "TRY", name: "Turkish Lira"),
        WatchCurrency(code: "KZT", name: "Kazakhstani Tenge"),
        WatchCurrency(code: "CNY", name: "Chinese Yuan"),
        WatchCurrency(code: "AED", name: "UAE Dirham"),
        WatchCurrency(code: "UZS", name: "Uzbekistani Som"),
        WatchCurrency(code: "BYN", name: "Belarusian Ruble"),
        WatchCurrency(code: "THB", name: "Thai Baht"),
        WatchCurrency(code: "UAH", name: "Ukrainian Hryvnia"),
        WatchCurrency(code: "GBP", name: "British Pound"),
        WatchCurrency(code: "JPY", name: "Japanese Yen"),
        WatchCurrency(code: "AMD", name: "Armenian Dram"),
        WatchCurrency(code: "GEL", name: "Georgian Lari"),
        WatchCurrency(code: "AUD", name: "Australian Dollar"),
        WatchCurrency(code: "CAD", name: "Canadian Dollar"),
        WatchCurrency(code: "CHF", name: "Swiss Franc"),
        WatchCurrency(code: "KRW", name: "South Korean Won"),
        WatchCurrency(code: "NZD", name: "New Zealand Dollar"),
        WatchCurrency(code: "SEK", name: "Swedish Krona"),
        WatchCurrency(code: "NOK", name: "Norwegian Krone"),
        WatchCurrency(code: "DKK", name: "Danish Krone"),
        WatchCurrency(code: "PLN", name: "Polish Zloty"),
        WatchCurrency(code: "AZN", name: "Azerbaijani Manat"),
        WatchCurrency(code: "DZD", name: "Algerian Dinar"),
        WatchCurrency(code: "BRL", name: "Brazilian Real"),
        WatchCurrency(code: "INR", name: "Indian Rupee"),
        WatchCurrency(code: "KGS", name: "Kyrgyzstani Som"),
        WatchCurrency(code: "TJS", name: "Tajikistani Somoni"),
        WatchCurrency(code: "RSD", name: "Serbian Dinar"),
        WatchCurrency(code: "CZK", name: "Czech Koruna"),
        WatchCurrency(code: "RON", name: "Romanian Leu"),
        WatchCurrency(code: "MDL", name: "Moldovan Leu"),
        WatchCurrency(code: "EGP", name: "Egyptian Pound"),
        WatchCurrency(code: "QAR", name: "Qatari Riyal"),
        WatchCurrency(code: "CUP", name: "Cuban Peso")
    ]

    private let defaults = UserDefaults.standard
    private let fromKey = "CoinVerterWatch.selectedFrom"
    private let toKey = "CoinVerterWatch.selectedTo"
    private let sourceKey = "CoinVerterWatch.selectedSource"

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

    private var backupRatesRUB: [String: Double] {
        let rubPerUSD = backupRatesUSD["RUB"] ?? 1.0
        var rates: [String: Double] = ["RUB": 1.0]
        for (code, usdRate) in backupRatesUSD where code != "RUB" {
            guard usdRate != 0 else { continue }
            rates[code] = rubPerUSD / usdRate
        }
        return rates
    }

    private var cbrRates: [String: Double] = [:]
    private var usdRates: [String: Double] = [:]
    private var conversionRate: Double = 0
    private var storedValue: Double = 0
    private var isPerformingOperation = false
    private var refreshTimer: Timer?

    init() {
        let fallbackFrom = WatchCurrency(code: "USD", name: "US Dollar")
        let fallbackTo = WatchCurrency(code: "RUB", name: "Russian Ruble")
        let savedFrom = defaults.string(forKey: fromKey)
        let savedTo = defaults.string(forKey: toKey)

        self.fromCurrency = currencies.first(where: { $0.code == savedFrom }) ?? fallbackFrom
        self.toCurrency = currencies.first(where: { $0.code == savedTo }) ?? fallbackTo

        if let savedSource = defaults.string(forKey: sourceKey),
           let rateSource = WatchRateSource(rawValue: savedSource) {
            self.source = rateSource
        }

        cbrRates = backupRatesRUB
        usdRates = backupRatesUSD
        syncSourceAvailability()
        updateConversionRate()
        scheduleAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    var availableSources: [WatchRateSource] {
        [.exchangeRate, .cbr]
    }

    var rateRows: [WatchCurrency] {
        currencies.filter { $0.code != fromCurrency.code }
    }

    func appendDigit(_ digit: String) {
        if isPerformingOperation {
            displayValue = digit
            isPerformingOperation = false
        } else if displayValue == "0" {
            displayValue = digit
        } else if displayValue.count < 10 {
            displayValue += digit
        }
        convert()
    }

    func appendDecimal() {
        if isPerformingOperation {
            displayValue = "0."
            isPerformingOperation = false
        } else if !displayValue.contains(".") && displayValue.count < 10 {
            displayValue += "."
        }
        convert()
    }

    func clear() {
        displayValue = "0"
        pendingOperation = .none
        storedValue = 0
        isPerformingOperation = false
        updateConversionRate()
    }

    func toggleSign() {
        guard displayValue != "0" else { return }
        if displayValue.hasPrefix("-") {
            displayValue.removeFirst()
        } else {
            displayValue = "-" + displayValue
        }
        convert()
    }

    func performOperation(_ operation: WatchCalculatorOperation) {
        guard let currentValue = numericDisplayValue else { return }

        if operation == .percent {
            displayValue = formatDisplayValue(currentValue / 100)
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
        convert()
    }

    func performEquals() {
        guard pendingOperation != .none, let currentValue = numericDisplayValue else { return }
        let result = calculateResult(storedValue, currentValue)
        displayValue = formatDisplayValue(result)
        pendingOperation = .none
        isPerformingOperation = true
        convert()
    }

    func swapCurrencies() {
        let currentSource = source
        let previousFrom = fromCurrency
        fromCurrency = toCurrency
        toCurrency = previousFrom
        if availableSources.contains(currentSource) {
            source = currentSource
        }
        updateConversionRate()
    }

    func cycleSource() {
        let sources = availableSources
        guard let index = sources.firstIndex(of: source) else {
            source = .exchangeRate
            return
        }
        source = sources[(index + 1) % sources.count]
        defaults.set(source.rawValue, forKey: sourceKey)
        updateConversionRate()
    }

    func refresh() async {
        isLoading = true
        async let cbrTask: [String: Double]? = fetchCBRRates()
        async let usdTask: [String: Double]? = fetchUSDRates()

        if let fetchedCBR = await cbrTask {
            cbrRates = fetchedCBR
        }
        if let fetchedUSD = await usdTask {
            usdRates = fetchedUSD
        }

        updateConversionRate()
        isLoading = false
    }

    private func scheduleAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.autoRefreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
    }

    func formattedBasePrice(for currency: WatchCurrency) -> String {
        guard let rate = basePrice(for: currency) else { return "—" }
        return formatRate(rate)
    }

    func basePrice(for currency: WatchCurrency) -> Double? {
        guard currency.code != fromCurrency.code else { return nil }

        switch effectiveSource {
        case .exchangeRate:
            let fromRate = usdRates[fromCurrency.code] ?? backupRatesUSD[fromCurrency.code]
            let toRate = usdRates[currency.code] ?? backupRatesUSD[currency.code]
            guard let fromRate, let toRate, toRate != 0 else { return nil }
            return fromRate / toRate
        case .cbr:
            let fromRate = cbrRates[fromCurrency.code] ?? backupRatesRUB[fromCurrency.code]
            let toRate = cbrRates[currency.code] ?? backupRatesRUB[currency.code]
            guard let fromRate, let toRate, fromRate != 0 else { return nil }
            return toRate / fromRate
        }
    }

    private var numericDisplayValue: Double? {
        Double(displayValue.replacingOccurrences(of: ",", with: "."))
    }

    private var effectiveSource: WatchRateSource {
        availableSources.contains(source) ? source : .exchangeRate
    }

    private func persistSelection() {
        defaults.set(fromCurrency.code, forKey: fromKey)
        defaults.set(toCurrency.code, forKey: toKey)
        defaults.set(source.rawValue, forKey: sourceKey)
    }

    private func syncSourceAvailability() {
        if !availableSources.contains(source) {
            source = .exchangeRate
        }
        persistSelection()
    }

    private func updateConversionRate() {
        switch effectiveSource {
        case .exchangeRate:
            let fromRate = usdRates[fromCurrency.code] ?? backupRatesUSD[fromCurrency.code] ?? 1
            let toRate = usdRates[toCurrency.code] ?? backupRatesUSD[toCurrency.code] ?? 1
            conversionRate = fromRate == 0 ? 0 : toRate / fromRate
        case .cbr:
            let fromRate = cbrRates[fromCurrency.code] ?? backupRatesRUB[fromCurrency.code] ?? 1
            let toRate = cbrRates[toCurrency.code] ?? backupRatesRUB[toCurrency.code] ?? 1
            conversionRate = toRate == 0 ? 0 : fromRate / toRate
        }

        calculationHistory = "1 \(fromCurrency.code) = \(formatRate(conversionRate)) \(toCurrency.code)"
        convert()
    }

    private func convert() {
        guard let value = numericDisplayValue else {
            convertedValue = "0"
            return
        }
        convertedValue = formatDisplayValue(value * conversionRate)
    }

    private func calculateResult(_ firstValue: Double, _ secondValue: Double) -> Double {
        switch pendingOperation {
        case .add: return firstValue + secondValue
        case .subtract: return firstValue - secondValue
        case .multiply: return firstValue * secondValue
        case .divide: return secondValue == 0 ? 0 : firstValue / secondValue
        case .percent: return firstValue * (secondValue / 100)
        case .none: return secondValue
        }
    }

    private func formatRate(_ value: Double) -> String {
        format(value, maxDigits: 4)
    }

    private func formatDisplayValue(_ value: Double) -> String {
        format(value, maxDigits: 2)
    }

    private func format(_ value: Double, maxDigits: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = maxDigits
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }

    private func fetchCBRRates() async -> [String: Double]? {
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(WatchCBRResponse.self, from: data)
            var rates: [String: Double] = ["RUB": 1]
            for (code, currency) in decoded.Valute {
                rates[code] = currency.Value / Double(currency.Nominal)
            }
            return rates
        } catch {
            return nil
        }
    }

    private func fetchUSDRates() async -> [String: Double]? {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }
            let decoded = try JSONDecoder().decode(WatchExchangeRatesResponse.self, from: data)
            return decoded.result == "success" ? decoded.rates : nil
        } catch {
            return nil
        }
    }
}

private struct WatchConverterView: View {
    @StateObject private var model = WatchConverterModel()
    @State private var showsBasePicker = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 8) {
                    header
                        .padding(.horizontal, 8)
                        .padding(.top, max(24, geometry.safeAreaInsets.top * 0.55))

                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(model.rateRows) { currency in
                                rateRow(currency)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, max(8, geometry.safeAreaInsets.bottom + 4))
                    }
                    .scrollIndicators(.hidden)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea(.container, edges: .top)
            }
        }
        .sheet(isPresented: $showsBasePicker) {
            WatchCurrencyPicker(
                currencies: model.currencies,
                selectedCurrency: $model.fromCurrency
            )
        }
        .task {
            await model.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Rates")
                .font(.system(size: 19, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)

            HStack(spacing: 6) {
                Button {
                    showsBasePicker = true
                } label: {
                    HStack(spacing: 5) {
                        Text(model.fromCurrency.flagEmoji)
                        Text(model.fromCurrency.code)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 9)
                    .frame(height: 28)
                    .background(Color.white.opacity(0.14), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    model.cycleSource()
                    Task { await model.refresh() }
                } label: {
                    Text(model.source.shortTitle)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.18))
                        .frame(minWidth: 36, minHeight: 28)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)

                Button {
                    Task { await model.refresh() }
                } label: {
                    ZStack {
                        if model.isLoading {
                            ProgressView()
                                .scaleEffect(0.62)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
        }
    }

    private func rateRow(_ currency: WatchCurrency) -> some View {
        HStack(spacing: 8) {
            Text(currency.flagEmoji)
                .font(.system(size: 22))
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 1) {
                Text(currency.code)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(currency.name)
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                Text(model.formattedBasePrice(for: currency))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Text("1 \(currency.code)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(red: 1.0, green: 0.58, blue: 0.18))
            }
            .frame(maxWidth: 72, alignment: .trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct WatchCurrencyPicker: View {
    let currencies: [WatchCurrency]
    @Binding var selectedCurrency: WatchCurrency
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(currencies) { currency in
            Button {
                selectedCurrency = currency
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text(currency.flagEmoji)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(currency.code)
                            .font(.headline)
                        Text(currency.name)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
    }
}

@main
struct CoinVerterWatchApp: App {
    init() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    var body: some Scene {
        WindowGroup {
            WatchConverterView()
        }
    }
}
