import WidgetKit
import SwiftUI
import AppIntents

// Резервные курсы (база USD) для использования при недоступности API
private let widgetBackupRatesUSD: [String: Double] = [
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

private func widgetBackupRatesRUB() -> [String: Double] {
    let rubPerUSD = widgetBackupRatesUSD["RUB"] ?? 1.0
    var rubRates: [String: Double] = ["RUB": 1.0]
    for (code, usdRate) in widgetBackupRatesUSD where code != "RUB" {
        guard usdRate != 0 else { continue }
        rubRates[code] = rubPerUSD / usdRate
    }
    return rubRates
}

// MARK: - Расширение для условного применения модификаторов
extension View {
    @ViewBuilder
    func ifAvailable(_ version: OperatingSystemVersion, transform: (Self) -> some View) -> some View {
        if #available(iOS 17, *) {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Модели данных виджета

// Структура для хранения данных о курсе валюты
struct CurrencyRate: Codable, Hashable {
    let code: String
    let name: String
    let rate: Double
    let flagEmoji: String
    
    init(code: String, name: String, rate: Double) {
        self.code = code
        self.name = name
        self.rate = rate
        
        // Установка эмодзи-флага в зависимости от кода валюты
        switch code {
        case "RUB": self.flagEmoji = "🇷🇺"
        case "USD": self.flagEmoji = "🇺🇸"
        case "EUR": self.flagEmoji = "🇪🇺"
        case "TRY": self.flagEmoji = "🇹🇷"
        case "KZT": self.flagEmoji = "🇰🇿"
        case "CNY": self.flagEmoji = "🇨🇳"
        case "AED": self.flagEmoji = "🇦🇪"
        case "UZS": self.flagEmoji = "🇺🇿"
        case "BYN": self.flagEmoji = "🇧🇾"
        case "THB": self.flagEmoji = "🇹🇭"
        case "UAH": self.flagEmoji = "🇺🇦"
        case "GBP": self.flagEmoji = "🇬🇧"
        case "JPY": self.flagEmoji = "🇯🇵"
        case "AMD": self.flagEmoji = "🇦🇲"
        case "GEL": self.flagEmoji = "🇬🇪"
        case "AUD": self.flagEmoji = "🇦🇺"
        case "CAD": self.flagEmoji = "🇨🇦"
        case "CHF": self.flagEmoji = "🇨🇭"
        case "KRW": self.flagEmoji = "🇰🇷"
        case "NZD": self.flagEmoji = "🇳🇿"
        case "SEK": self.flagEmoji = "🇸🇪"
        case "NOK": self.flagEmoji = "🇳🇴"
        case "DKK": self.flagEmoji = "🇩🇰"
        case "PLN": self.flagEmoji = "🇵🇱"
        case "AZN": self.flagEmoji = "🇦🇿"
        case "DZD": self.flagEmoji = "🇩🇿"
        case "BRL": self.flagEmoji = "🇧🇷"
        case "INR": self.flagEmoji = "🇮🇳"
        case "KGS": self.flagEmoji = "🇰🇬"
        case "TJS": self.flagEmoji = "🇹🇯"
        case "RSD": self.flagEmoji = "🇷🇸"
        case "CZK": self.flagEmoji = "🇨🇿"
        case "RON": self.flagEmoji = "🇷🇴"
        case "MDL": self.flagEmoji = "🇲🇩"
        case "EGP": self.flagEmoji = "🇪🇬"
        case "QAR": self.flagEmoji = "🇶🇦"
        case "CUP": self.flagEmoji = "🇨🇺"
        default: self.flagEmoji = "🏳️"
        }
    }
}

// Структура для декодирования ответа ExchangeRate API
struct ExchangeRatesResponse: Codable {
    let result: String
    let base_code: String
    let time_last_update_unix: Int
    let rates: [String: Double]
}

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

// Модель с данными для виджета
struct CurrencyEntry: TimelineEntry {
    let date: Date
    let baseCode: String
    let rates: [CurrencyRate]
    let lastUpdated: String
}

// MARK: - Провайдер для виджета

struct Provider: AppIntentTimelineProvider {
    // Лимитируем частоту сетевых запросов для защиты от блокировок API.
    private static let apiMinRequestInterval: TimeInterval = 2.0
    private static let cbrLastRequestKey = "CurrencyWidget.iOS.cbr.lastRequest"
    private static let usdLastRequestKey = "CurrencyWidget.iOS.usd.lastRequest"
    private static let cbrRatesCacheKey = "CurrencyWidget.iOS.cbr.cachedRates"
    private static let usdRatesCacheKey = "CurrencyWidget.iOS.usd.cachedRates"

    func placeholder(in context: Context) -> CurrencyEntry {
        CurrencyEntry(
            date: Date(),
            baseCode: "RUB",
            rates: getPreviewRates(),
            lastUpdated: formattedUpdatedAt(Date())
        )
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> CurrencyEntry {
        if context.isPreview {
            return previewEntry(for: configuration)
        }
        return await fetchEntry(for: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<CurrencyEntry> {
        let entry = await fetchEntry(for: configuration)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }
    
    private func fetchEntry(for configuration: ConfigurationAppIntent) async -> CurrencyEntry {
        let base = configuration.baseCurrency
        let selectedCodes = normalizedCodes(from: configuration)
        let selectedRateSource = effectiveRateSource(
            from: configuration,
            base: base,
            selectedCodes: selectedCodes
        )
        
        let needsCBR = selectedRateSource == .cbr
        let needsUSD = selectedRateSource == .exchangeRate
        
        async let cbrTask: [String: Double]? = needsCBR ? fetchCBRRates() : nil
        async let usdTask: [String: Double]? = needsUSD ? fetchUSDRates() : nil
        
        let cbrRates = await cbrTask ?? widgetBackupRatesRUB()
        let usdRates = await usdTask ?? widgetBackupRatesUSD
        
        let rates = buildRates(
            baseCode: base.rawValue,
            selectedCodes: selectedCodes,
            cbrRates: cbrRates,
            usdRates: usdRates,
            source: selectedRateSource
        )
        
        let updatedAt = Date()
        return CurrencyEntry(
            date: updatedAt,
            baseCode: base.rawValue,
            rates: rates.isEmpty ? getPreviewRates() : rates,
            lastUpdated: formattedUpdatedAt(updatedAt)
        )
    }
    
    private func normalizedCodes(from configuration: ConfigurationAppIntent) -> [CurrencyCode] {
        var codes = configuration.currencies
        if codes.isEmpty {
            codes = ConfigurationAppIntent.defaultCurrencies
        }
        let unique = Set(codes)
        var ordered = CurrencyCode.allCases.filter { unique.contains($0) && $0 != configuration.baseCurrency }
        if ordered.isEmpty {
            let fallbackSet = Set(ConfigurationAppIntent.defaultCurrencies)
            ordered = CurrencyCode.allCases.filter { fallbackSet.contains($0) && $0 != configuration.baseCurrency }
        }
        return ordered
    }
    
    private func effectiveRateSource(
        from configuration: ConfigurationAppIntent,
        base: CurrencyCode,
        selectedCodes: [CurrencyCode]
    ) -> WidgetRateSource {
        let hasRublePair = base == .rub || selectedCodes.contains(.rub)
        return hasRublePair ? configuration.rateSource : .exchangeRate
    }
    
    private func buildRates(
        baseCode: String,
        selectedCodes: [CurrencyCode],
        cbrRates: [String: Double],
        usdRates: [String: Double],
        source: WidgetRateSource
    ) -> [CurrencyRate] {
        var rates: [CurrencyRate] = []
        for code in selectedCodes {
            let target = code.rawValue
            if let rate = computeRate(
                base: baseCode,
                target: target,
                cbrRates: cbrRates,
                usdRates: usdRates,
                source: source
            ) {
                rates.append(CurrencyRate(code: target, name: getCurrencyName(for: target), rate: rate))
            }
        }
        return rates
    }
    
    private func computeRate(
        base: String,
        target: String,
        cbrRates: [String: Double],
        usdRates: [String: Double],
        source: WidgetRateSource
    ) -> Double? {
        guard base != target else { return nil }
        
        if source == .cbr {
            guard
                let rubPerBase = cbrRates[base],
                let rubPerTarget = cbrRates[target],
                rubPerBase != 0
            else {
                return nil
            }
            return rubPerTarget / rubPerBase
        }
        
        guard let usdBase = usdRates[base], let usdTarget = usdRates[target], usdTarget != 0 else {
            return nil
        }
        
        return usdBase / usdTarget
    }
    
    private func fetchCBRRates() async -> [String: Double]? {
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        
        if let lastRequest = defaults.object(forKey: Self.cbrLastRequestKey) as? TimeInterval,
           now - lastRequest < Self.apiMinRequestInterval {
            return defaults.dictionary(forKey: Self.cbrRatesCacheKey) as? [String: Double]
        }
        
        defaults.set(now, forKey: Self.cbrLastRequestKey)
        
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else {
            return defaults.dictionary(forKey: Self.cbrRatesCacheKey) as? [String: Double]
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return defaults.dictionary(forKey: Self.cbrRatesCacheKey) as? [String: Double]
            }
            
            let cbrResponse = try JSONDecoder().decode(CBRResponse.self, from: data)
            var rates: [String: Double] = ["RUB": 1.0]
            for (code, currencyData) in cbrResponse.Valute {
                let rateInRub = currencyData.Value / Double(currencyData.Nominal)
                rates[code] = rateInRub
            }
            defaults.set(rates, forKey: Self.cbrRatesCacheKey)
            return rates
        } catch {
            return defaults.dictionary(forKey: Self.cbrRatesCacheKey) as? [String: Double]
        }
    }
    
    private func fetchUSDRates() async -> [String: Double]? {
        let defaults = UserDefaults.standard
        let now = Date().timeIntervalSince1970
        
        if let lastRequest = defaults.object(forKey: Self.usdLastRequestKey) as? TimeInterval,
           now - lastRequest < Self.apiMinRequestInterval {
            return defaults.dictionary(forKey: Self.usdRatesCacheKey) as? [String: Double]
        }
        
        defaults.set(now, forKey: Self.usdLastRequestKey)
        
        guard let url = URL(string: "https://open.er-api.com/v6/latest/USD") else {
            return defaults.dictionary(forKey: Self.usdRatesCacheKey) as? [String: Double]
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return defaults.dictionary(forKey: Self.usdRatesCacheKey) as? [String: Double]
            }
            
            let ratesResponse = try JSONDecoder().decode(ExchangeRatesResponse.self, from: data)
            guard ratesResponse.result == "success" else {
                return defaults.dictionary(forKey: Self.usdRatesCacheKey) as? [String: Double]
            }
            defaults.set(ratesResponse.rates, forKey: Self.usdRatesCacheKey)
            return ratesResponse.rates
        } catch {
            return defaults.dictionary(forKey: Self.usdRatesCacheKey) as? [String: Double]
        }
    }
    
    private func previewEntry(for configuration: ConfigurationAppIntent) -> CurrencyEntry {
        let baseCode = configuration.baseCurrency.rawValue
        let selectedCodes = normalizedCodes(from: configuration)
        let previewRates = getPreviewRates()
        let selectedSet = Set(selectedCodes.map { $0.rawValue })
        let filtered = previewRates.filter { selectedSet.contains($0.code) }
        let updatedAt = Date()
        return CurrencyEntry(
            date: updatedAt,
            baseCode: baseCode,
            rates: filtered.isEmpty ? previewRates : filtered,
            lastUpdated: formattedUpdatedAt(updatedAt)
        )
    }
    
    private func formattedUpdatedAt(_ date: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return dateFormatter.string(from: date)
    }
    
    private func getCurrencyName(for code: String) -> String {
        WidgetL10n.currencyName(code)
    }
    
    private func getPreviewRates() -> [CurrencyRate] {
        [
            CurrencyRate(code: "USD", name: WidgetL10n.currencyName("USD"), rate: 93.5),
            CurrencyRate(code: "EUR", name: WidgetL10n.currencyName("EUR"), rate: 100.2),
            CurrencyRate(code: "CNY", name: WidgetL10n.currencyName("CNY"), rate: 12.8),
            CurrencyRate(code: "TRY", name: WidgetL10n.currencyName("TRY"), rate: 2.8),
            CurrencyRate(code: "KZT", name: WidgetL10n.currencyName("KZT"), rate: 0.2)
        ]
    }
}

// MARK: - Представления виджета

// Компактная ячейка для отображения валюты
struct CurrencyGridCell: View {
    var rate: CurrencyRate
    var baseCode: String
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text(rate.flagEmoji)
                    .font(.system(size: 16))
                
                Text(rate.code)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
            
            Text(String(format: "%.2f %@", rate.rate, baseCode))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color(red: 0.1, green: 0.15, blue: 0.25) : Color(red: 0.9, green: 0.95, blue: 1.0))
        .cornerRadius(8)
    }
}

// Виджет в маленьком размере
struct CurrencyWidgetSmallView: View {
    var entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    
    private func getMainCurrencies() -> [CurrencyRate] {
        Array(entry.rates.prefix(2))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            let currencies = getMainCurrencies()
            
            // Сетка валют 2x1
            VStack(spacing: 8) {
                ForEach(currencies, id: \.code) { rate in
                    CurrencyGridCell(rate: rate, baseCode: entry.baseCode)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .edgesIgnoringSafeArea(.all)
    }
}

// Виджет среднего размера - обновленная версия с сеткой 2x2
struct CurrencyWidgetMediumView: View {
    var entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    
    // Функция для разделения валют на две строки
    private func currencyRows() -> [[CurrencyRate]] {
        let orderedRates = entry.rates
        let firstRow = Array(orderedRates.prefix(2))
        let secondRow = Array(orderedRates.dropFirst(2).prefix(2))
        
        return [firstRow, secondRow].filter { !$0.isEmpty }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Сетка валют 2x2
            VStack(spacing: 8) {
                ForEach(currencyRows(), id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.code) { rate in
                            CurrencyGridCell(rate: rate, baseCode: entry.baseCode)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Основная конфигурация виджета

struct CurrencyWidget: Widget {
    let kind: String = "CurrencyWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            Group {
                GeometryReader { geometry in
                    if geometry.size.width < 170 {
                        CurrencyWidgetSmallView(entry: entry)
                    } else {
                        CurrencyWidgetMediumView(entry: entry)
                    }
                }
            }
            // Для всех версий iOS
            // Применяем containerBackground, если он поддерживается
            .ifAvailable(OperatingSystemVersion(majorVersion: 17, minorVersion: 0, patchVersion: 0)) { view in
                view.containerBackground(for: .widget) {
                    Color.clear
                }
            }
        }
        .configurationDisplayName("widget.display_name")
        .description("widget.description")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Превью виджетов

struct CurrencyWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = CurrencyEntry(
            date: Date(),
            baseCode: "RUB",
            rates: [
                CurrencyRate(code: "USD", name: WidgetL10n.currencyName("USD"), rate: 85.57),
                CurrencyRate(code: "EUR", name: WidgetL10n.currencyName("EUR"), rate: 93.61),
                CurrencyRate(code: "TRY", name: WidgetL10n.currencyName("TRY"), rate: 2.65),
                CurrencyRate(code: "AED", name: WidgetL10n.currencyName("AED"), rate: 23.30)
            ],
            lastUpdated: "14.03.2025, 10:00"
        )
        
        Group {
            CurrencyWidgetSmallView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Маленький")
                .environment(\.colorScheme, .dark)
            
            CurrencyWidgetSmallView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemSmall))
                .previewDisplayName("Маленький (Светлая тема)")
                .environment(\.colorScheme, .light)
            
            CurrencyWidgetMediumView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Средний")
                .environment(\.colorScheme, .dark)
            
            CurrencyWidgetMediumView(entry: sampleEntry)
                .previewContext(WidgetPreviewContext(family: .systemMedium))
                .previewDisplayName("Средний (Светлая тема)")
                .environment(\.colorScheme, .light)
        }
    }
}
