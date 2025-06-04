import SwiftUI
import WidgetKit

// MARK: - Модели данных

// Структура для декодирования ответа API валют
struct ExchangeRatesResponse: Codable {
    let result: String
    let base_code: String
    let time_last_update_unix: Int
    let rates: [String: Double]
}

// Структура для валюты в виджете
struct CurrencyWidgetItem: Identifiable, Hashable {
    var id = UUID()
    var code: String
    var name: String
    var rate: Double
    var flagEmoji: String
    
    // Инициализатор из основного приложения
    init(from appCurrency: Currency, rate: Double) {
        self.code = appCurrency.code
        self.name = appCurrency.name
        self.rate = rate
        self.flagEmoji = appCurrency.flagEmoji
    }
    
    // Инициализатор для тестовых данных
    init(code: String, name: String, rate: Double, flagEmoji: String) {
        self.code = code
        self.name = name
        self.rate = rate
        self.flagEmoji = flagEmoji
    }
}

// MARK: - Provider для обновления виджета

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> CurrencyWidgetEntry {
        CurrencyWidgetEntry(date: Date(), currencies: getPreviewCurrencies())
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CurrencyWidgetEntry) -> Void) {
        // Для предпросмотра используем заглушки данных
        if context.isPreview {
            let entry = CurrencyWidgetEntry(date: Date(), currencies: getPreviewCurrencies())
            completion(entry)
            return
        }
        
        // В реальном использовании загружаем данные
        fetchExchangeRates { currencies in
            let entry = CurrencyWidgetEntry(date: Date(), currencies: currencies)
            completion(entry)
        }
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrencyWidgetEntry>) -> Void) {
        fetchExchangeRates { currencies in
            let entry = CurrencyWidgetEntry(date: Date(), currencies: currencies)
            
            // Обновление каждый час
            let nextUpdateDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdateDate))
            
            completion(timeline)
        }
    }
    
    // Функция для получения курсов валют через API
    private func fetchExchangeRates(completion: @escaping ([CurrencyWidgetItem]) -> Void) {
        guard let url = URL(string: "https://open.er-api.com/v6/latest/RUB") else {
            completion(getPreviewCurrencies())
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard error == nil, let data = data else {
                completion(getPreviewCurrencies())
                return
            }
            
            do {
                let ratesResponse = try JSONDecoder().decode(ExchangeRatesResponse.self, from: data)
                
                // Создаем список валют для виджета
                var widgetCurrencies: [CurrencyWidgetItem] = []
                
                // Список избранных валют для отображения в виджете
                let favoriteCurrencyCodes = ["USD", "EUR", "CNY", "TRY", "KZT"]
                
                for code in favoriteCurrencyCodes {
                    if let rate = ratesResponse.rates[code], code != "RUB" {
                        // Инвертируем курс, так как API возвращает курс относительно базовой валюты
                        let invertedRate = 1.0 / rate
                        
                        let currency = CurrencyWidgetItem(
                            code: code,
                            name: getCurrencyName(for: code),
                            rate: invertedRate,
                            flagEmoji: getCurrencyFlag(for: code)
                        )
                        widgetCurrencies.append(currency)
                    }
                }
                
                completion(widgetCurrencies)
                
            } catch {
                completion(getPreviewCurrencies())
            }
        }.resume()
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
        return [
            CurrencyWidgetItem(code: "USD", name: "Доллар США", rate: 93.5, flagEmoji: "🇺🇸"),
            CurrencyWidgetItem(code: "EUR", name: "Евро", rate: 100.2, flagEmoji: "🇪🇺"),
            CurrencyWidgetItem(code: "CNY", name: "Китайский юань", rate: 12.8, flagEmoji: "🇨🇳"),
            CurrencyWidgetItem(code: "TRY", name: "Турецкая лира", rate: 2.8, flagEmoji: "🇹🇷"),
            CurrencyWidgetItem(code: "KZT", name: "Казахский тенге", rate: 0.2, flagEmoji: "🇰🇿")
        ]
    }
}

// MARK: - Модель данных для виджета

struct CurrencyWidgetEntry: TimelineEntry {
    let date: Date
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
                
                Text("₽")
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
                    
                    Text(String(format: "%.2f", currency.rate))
                        .font(.subheadline)
                        .foregroundColor(.white)
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
                Text("Курсы валют к рублю")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("₽")
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
                    
                    Text(String(format: "%.2f", currency.rate))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
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
                Text("Курсы валют к рублю")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("₽")
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
                    CurrencyCard(currency: currency)
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
            
            Text(String(format: "%.2f ₽", currency.rate))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
        .padding()
        .frame(height: 120)
        .background(Color(UIColor.darkGray).opacity(0.5))
        .cornerRadius(12)
    }
}

// MARK: - Виджет

struct CurrencyWidget: Widget {
    let kind: String = "CurrencyWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            CurrencyWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Курсы валют")
        .description("Актуальные курсы основных валют к рублю")
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
            CurrencyWidgetEntryView(entry: CurrencyWidgetEntry(date: Date(), currencies: [
                CurrencyWidgetItem(code: "USD", name: "Доллар США", rate: 93.5, flagEmoji: "🇺🇸"),
                CurrencyWidgetItem(code: "EUR", name: "Евро", rate: 100.2, flagEmoji: "🇪🇺"),
                CurrencyWidgetItem(code: "CNY", name: "Китайский юань", rate: 12.8, flagEmoji: "🇨🇳"),
                CurrencyWidgetItem(code: "TRY", name: "Турецкая лира", rate: 2.8, flagEmoji: "🇹🇷"),
                CurrencyWidgetItem(code: "KZT", name: "Казахский тенге", rate: 0.2, flagEmoji: "🇰🇿")
            ]))
            .previewContext(WidgetPreviewContext(family: .systemSmall))
            .preferredColorScheme(.dark)
            
            CurrencyWidgetEntryView(entry: CurrencyWidgetEntry(date: Date(), currencies: [
                CurrencyWidgetItem(code: "USD", name: "Доллар США", rate: 93.5, flagEmoji: "🇺🇸"),
                CurrencyWidgetItem(code: "EUR", name: "Евро", rate: 100.2, flagEmoji: "🇪🇺"),
                CurrencyWidgetItem(code: "CNY", name: "Китайский юань", rate: 12.8, flagEmoji: "🇨🇳"),
                CurrencyWidgetItem(code: "TRY", name: "Турецкая лира", rate: 2.8, flagEmoji: "🇹🇷"),
                CurrencyWidgetItem(code: "KZT", name: "Казахский тенге", rate: 0.2, flagEmoji: "🇰🇿")
            ]))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
            .preferredColorScheme(.dark)
            
            CurrencyWidgetEntryView(entry: CurrencyWidgetEntry(date: Date(), currencies: [
                CurrencyWidgetItem(code: "USD", name: "Доллар США", rate: 93.5, flagEmoji: "🇺🇸"),
                CurrencyWidgetItem(code: "EUR", name: "Евро", rate: 100.2, flagEmoji: "🇪🇺"),
                CurrencyWidgetItem(code: "CNY", name: "Китайский юань", rate: 12.8, flagEmoji: "🇨🇳"),
                CurrencyWidgetItem(code: "TRY", name: "Турецкая лира", rate: 2.8, flagEmoji: "🇹🇷"),
                CurrencyWidgetItem(code: "KZT", name: "Казахский тенге", rate: 0.2, flagEmoji: "🇰🇿")
            ]))
            .previewContext(WidgetPreviewContext(family: .systemLarge))
            .preferredColorScheme(.dark)
        }
    }
}
