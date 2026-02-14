import SwiftUI
import WidgetKit
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
    "UAH": 39.5
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

// MARK: - Модели данных

// Структура для декодирования ответа API валют
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

private struct WidgetRatesResult {
    let updatedAt: Date
    let currencies: [CurrencyWidgetItem]
}

enum RateTrend: String, Codable {
    case up
    case down
    case flat
    case unknown
    
    var symbolName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .flat: return "minus"
        case .unknown: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .red
        case .down: return .green
        case .flat: return .gray
        case .unknown: return .gray
        }
    }
}

// Структура для валюты в виджете
struct CurrencyWidgetItem: Identifiable, Hashable {
    var id = UUID()
    var code: String
    var name: String
    var rate: Double
    var flagEmoji: String
    var trend: RateTrend
    
    // Инициализатор из основного приложения
    init(from appCurrency: Currency, rate: Double, trend: RateTrend = .unknown) {
        self.code = appCurrency.code
        self.name = appCurrency.name
        self.rate = rate
        self.flagEmoji = appCurrency.flagEmoji
        self.trend = trend
    }
    
    // Инициализатор для тестовых данных
    init(code: String, name: String, rate: Double, flagEmoji: String, trend: RateTrend = .unknown) {
        self.code = code
        self.name = name
        self.rate = rate
        self.flagEmoji = flagEmoji
        self.trend = trend
    }
}

// MARK: - Provider для обновления виджета

struct Provider: AppIntentTimelineProvider {
    // Лимитируем частоту сетевых запросов для защиты от блокировок API.
    private static let apiMinRequestInterval: TimeInterval = 2.0
    private static let cbrLastRequestKey = "CurrencyWidgetExtension.iOS.cbr.lastRequest"
    private static let usdLastRequestKey = "CurrencyWidgetExtension.iOS.usd.lastRequest"
    private static let cbrRatesCacheKey = "CurrencyWidgetExtension.iOS.cbr.cachedRates"
    private static let usdRatesCacheKey = "CurrencyWidgetExtension.iOS.usd.cachedRates"

    func placeholder(in context: Context) -> CurrencyWidgetEntry {
        CurrencyWidgetEntry(date: Date(), baseCode: "RUB", currencies: getPreviewCurrencies())
    }
    
    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> CurrencyWidgetEntry {
        if context.isPreview {
            return previewEntry(for: configuration)
        }
        
        let result = await fetchRates(for: configuration)
        return CurrencyWidgetEntry(
            date: result.updatedAt,
            baseCode: configuration.baseCurrency.rawValue,
            currencies: result.currencies
        )
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<CurrencyWidgetEntry> {
        let result = await fetchRates(for: configuration)
        let entry = CurrencyWidgetEntry(
            date: result.updatedAt,
            baseCode: configuration.baseCurrency.rawValue,
            currencies: result.currencies
        )
        
        let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 3, to: Date()) ?? Date()
        return Timeline(entries: [entry], policy: .after(nextUpdateDate))
    }
    
    private func fetchRates(for configuration: ConfigurationAppIntent) async -> WidgetRatesResult {
        let base = configuration.baseCurrency
        let selectedCodes = normalizedCodes(from: configuration)
        
        let needsCBR = base == .rub || selectedCodes.contains(.rub)
        let needsUSD = base != .rub && selectedCodes.contains(where: { $0 != .rub })
        
        async let cbrTask: [String: Double]? = needsCBR ? fetchCBRRates() : nil
        async let usdTask: [String: Double]? = needsUSD ? fetchUSDRates() : nil
        
        let cbrRates = await cbrTask ?? widgetBackupRatesRUB()
        let usdRates = await usdTask ?? widgetBackupRatesUSD
        
        let currencies = buildCurrencies(
            baseCode: base.rawValue,
            selectedCodes: selectedCodes,
            cbrRates: cbrRates,
            usdRates: usdRates
        )
        
        if currencies.isEmpty {
            return makeFallbackResult(baseCode: base.rawValue, selectedCodes: selectedCodes)
        }
        
        return WidgetRatesResult(updatedAt: Date(), currencies: currencies)
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
    
    private func buildCurrencies(
        baseCode: String,
        selectedCodes: [CurrencyCode],
        cbrRates: [String: Double],
        usdRates: [String: Double]
    ) -> [CurrencyWidgetItem] {
        var items: [CurrencyWidgetItem] = []
        let defaultsKey = "CurrencyWidgetPreviousRates_\(baseCode)"
        let previousRates = UserDefaults.standard.dictionary(forKey: defaultsKey) as? [String: Double] ?? [:]
        var updatedRates: [String: Double] = [:]
        
        for code in selectedCodes {
            let target = code.rawValue
            if let rate = computeRate(base: baseCode, target: target, cbrRates: cbrRates, usdRates: usdRates) {
                let trend = getTrend(for: rate, previous: previousRates[target])
                let currency = CurrencyWidgetItem(
                    code: target,
                    name: getCurrencyName(for: target),
                    rate: rate,
                    flagEmoji: getCurrencyFlag(for: target),
                    trend: trend
                )
                items.append(currency)
                updatedRates[target] = rate
            }
        }
        
        if !updatedRates.isEmpty {
            UserDefaults.standard.set(updatedRates, forKey: defaultsKey)
        }
        
        return items
    }
    
    private func computeRate(
        base: String,
        target: String,
        cbrRates: [String: Double],
        usdRates: [String: Double]
    ) -> Double? {
        guard base != target else { return nil }
        
        if base == "RUB" {
            return cbrRates[target]
        }
        
        if target == "RUB" {
            guard let rubPerBase = cbrRates[base], rubPerBase != 0 else { return nil }
            return 1.0 / rubPerBase
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
    
    private func previewEntry(for configuration: ConfigurationAppIntent) -> CurrencyWidgetEntry {
        let baseCode = configuration.baseCurrency.rawValue
        let selectedCodes = normalizedCodes(from: configuration)
        let preview = getPreviewCurrencies()
        let selectedSet = Set(selectedCodes.map { $0.rawValue })
        let filtered = preview.filter { selectedSet.contains($0.code) }
        return CurrencyWidgetEntry(
            date: Date(),
            baseCode: baseCode,
            currencies: filtered.isEmpty ? preview : filtered
        )
    }
    
    private func makeFallbackResult(baseCode: String, selectedCodes: [CurrencyCode]) -> WidgetRatesResult {
        let currencies = buildCurrencies(
            baseCode: baseCode,
            selectedCodes: selectedCodes,
            cbrRates: widgetBackupRatesRUB(),
            usdRates: widgetBackupRatesUSD
        )
        if currencies.isEmpty {
            return WidgetRatesResult(updatedAt: Date(), currencies: getPreviewCurrencies())
        }
        return WidgetRatesResult(updatedAt: Date(), currencies: currencies)
    }
    
    private func getTrend(for current: Double, previous: Double?) -> RateTrend {
        guard let previous else { return .unknown }
        let delta = current - previous
        if abs(delta) < 0.0001 {
            return .flat
        }
        return delta > 0 ? .up : .down
    }
    
    // Получаем название валюты по коду
    private func getCurrencyName(for code: String) -> String {
        switch code {
        case "RUB": return "Российский рубль"
        case "USD": return "Доллар США"
        case "EUR": return "Евро"
        case "TRY": return "Турецкая лира"
        case "KZT": return "Казахский тенге"
        case "CNY": return "Китайский юань"
        case "AED": return "Дирхам ОАЭ"
        case "UZS": return "Узбекский сум"
        case "BYN": return "Белорусский рубль"
        case "THB": return "Таиландский бат"
        case "UAH": return "Украинская гривна"
        case "GBP": return "Британский фунт"
        case "JPY": return "Японская йена"
        default: return code
        }
    }
    
    // Получаем флаг валюты по коду
    private func getCurrencyFlag(for code: String) -> String {
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
    
    // Тестовые данные для предпросмотра
    private func getPreviewCurrencies() -> [CurrencyWidgetItem] {
        [
            CurrencyWidgetItem(code: "USD", name: "Доллар США", rate: 93.5, flagEmoji: "🇺🇸", trend: .up),
            CurrencyWidgetItem(code: "EUR", name: "Евро", rate: 100.2, flagEmoji: "🇪🇺", trend: .down),
            CurrencyWidgetItem(code: "CNY", name: "Китайский юань", rate: 12.8, flagEmoji: "🇨🇳", trend: .flat),
            CurrencyWidgetItem(code: "TRY", name: "Турецкая лира", rate: 2.8, flagEmoji: "🇹🇷", trend: .down),
            CurrencyWidgetItem(code: "KZT", name: "Казахский тенге", rate: 0.2, flagEmoji: "🇰🇿", trend: .up)
        ]
    }
}

// MARK: - Модель данных для виджета

struct CurrencyWidgetEntry: TimelineEntry {
    let date: Date
    let baseCode: String
    let currencies: [CurrencyWidgetItem]
}

// MARK: - Маленький виджет

struct CurrencySmallWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Курсы валют")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(entry.baseCode)
                    .font(.headline)
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Отображаем первые 3 валюты для маленького виджета
            ForEach(Array(entry.currencies.prefix(3))) { currency in
                HStack {
                    Text(currency.flagEmoji)
                        .font(.subheadline)
                    
                    Text(currency.code)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(String(format: "%.2f", currency.rate))
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        TrendArrow(trend: currency.trend)
                    }
                }
                .padding(.horizontal, 12)
            }
            
            Spacer()
            
            Text("Обновлено: \(formattedDate(entry.date))")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(UIColor.darkGray), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Средний виджет

struct CurrencyMediumWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Курсы валют к \(entry.baseCode)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(entry.baseCode)
                    .font(.headline)
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            // Отображаем все валюты
            ForEach(entry.currencies) { currency in
                HStack {
                    Text(currency.flagEmoji)
                        .font(.system(size: 16))
                    
                    Text(currency.code)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(currency.name)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(String(format: "%.2f", currency.rate))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        TrendArrow(trend: currency.trend)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            
            Spacer()
            
            Text("Обновлено: \(formattedDate(entry.date))")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(.bottom, 8)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(UIColor.darkGray), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM, HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Большой виджет

struct CurrencyLargeWidgetView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack {
            HStack {
                Text("Курсы валют к \(entry.baseCode)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text(entry.baseCode)
                    .font(.title3)
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            Divider()
                .background(Color.gray.opacity(0.3))
                .padding(.horizontal, 20)
            
            // Grid для отображения валют
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                ForEach(entry.currencies) { currency in
                    CurrencyCard(currency: currency, baseCode: entry.baseCode)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            
            Spacer()
            
            HStack {
                Spacer()
                Text("Обновлено: \(formattedDate(entry.date))")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color(UIColor.darkGray), Color.black]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy, HH:mm"
        return formatter.string(from: date)
    }
}

// Карточка валюты для большого виджета
struct CurrencyCard: View {
    var currency: CurrencyWidgetItem
    var baseCode: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(currency.flagEmoji)
                    .font(.title3)
                
                Text(currency.code)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            Text(currency.name)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(1)
            
            Spacer()
            
            HStack(spacing: 6) {
                Text(String(format: "%.2f %@", currency.rate, baseCode))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                TrendArrow(trend: currency.trend)
            }
        }
        .padding()
        .frame(height: 120)
        .background(Color(UIColor.darkGray).opacity(0.5))
        .cornerRadius(12)
    }
}

struct TrendArrow: View {
    var trend: RateTrend
    
    var body: some View {
        Image(systemName: trend.symbolName)
            .font(.caption2)
            .foregroundColor(trend.color)
    }
}

// MARK: - Виджет

struct CurrencyWidget: Widget {
    let kind: String = "CurrencyWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            CurrencyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Курсы валют")
        .description("Актуальные курсы выбранных валют к базовой валюте")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct CurrencyWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    
    var body: some View {
        switch family {
        case .systemSmall:
            CurrencySmallWidgetView(entry: entry)
        case .systemMedium:
            CurrencyMediumWidgetView(entry: entry)
        case .systemLarge:
            CurrencyLargeWidgetView(entry: entry)
        @unknown default:
            CurrencyMediumWidgetView(entry: entry)
        }
    }
}

// MARK: - Превью

struct CurrencyWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            CurrencyWidgetEntryView(entry: CurrencyWidgetEntry(date: Date(), baseCode: "RUB", currencies: [
                CurrencyWidgetItem(code: "USD", name: "Доллар США", rate: 93.5, flagEmoji: "🇺🇸", trend: .up),
                CurrencyWidgetItem(code: "EUR", name: "Евро", rate: 100.2, flagEmoji: "🇪🇺", trend: .down),
                CurrencyWidgetItem(code: "CNY", name: "Китайский юань", rate: 12.8, flagEmoji: "🇨🇳", trend: .flat),
                CurrencyWidgetItem(code: "TRY", name: "Турецкая лира", rate: 2.8, flagEmoji: "🇹🇷", trend: .down),
                CurrencyWidgetItem(code: "KZT", name: "Казахский тенге", rate: 0.2, flagEmoji: "🇰🇿", trend: .up)
            ]))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .preferredColorScheme(.dark)
            
            CurrencyWidgetEntryView(entry: CurrencyWidgetEntry(date: Date(), baseCode: "RUB", currencies: [
                CurrencyWidgetItem(code: "USD", name: "Доллар США", rate: 93.5, flagEmoji: "🇺🇸", trend: .up),
                CurrencyWidgetItem(code: "EUR", name: "Евро", rate: 100.2, flagEmoji: "🇪🇺", trend: .down),
                CurrencyWidgetItem(code: "CNY", name: "Китайский юань", rate: 12.8, flagEmoji: "🇨🇳", trend: .flat),
                CurrencyWidgetItem(code: "TRY", name: "Турецкая лира", rate: 2.8, flagEmoji: "🇹🇷", trend: .down),
                CurrencyWidgetItem(code: "KZT", name: "Казахский тенге", rate: 0.2, flagEmoji: "🇰🇿", trend: .up)
            ]))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .preferredColorScheme(.dark)
            
            CurrencyWidgetEntryView(entry: CurrencyWidgetEntry(date: Date(), baseCode: "RUB", currencies: [
                CurrencyWidgetItem(code: "USD", name: "Доллар США", rate: 93.5, flagEmoji: "🇺🇸", trend: .up),
                CurrencyWidgetItem(code: "EUR", name: "Евро", rate: 100.2, flagEmoji: "🇪🇺", trend: .down),
                CurrencyWidgetItem(code: "CNY", name: "Китайский юань", rate: 12.8, flagEmoji: "🇨🇳", trend: .flat),
                CurrencyWidgetItem(code: "TRY", name: "Турецкая лира", rate: 2.8, flagEmoji: "🇹🇷", trend: .down),
                CurrencyWidgetItem(code: "KZT", name: "Казахский тенге", rate: 0.2, flagEmoji: "🇰🇿", trend: .up)
            ]))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .preferredColorScheme(.dark)
        }
    }
}
