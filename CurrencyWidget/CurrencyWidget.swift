import WidgetKit
import SwiftUI
import Intents

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
        case "USD": self.flagEmoji = "🇺🇸"
        case "EUR": self.flagEmoji = "🇪🇺"
        case "CNY": self.flagEmoji = "🇨🇳"
        case "TRY": self.flagEmoji = "🇹🇷"
        case "AED": self.flagEmoji = "🇦🇪"
        default: self.flagEmoji = "🏳️"
        }
    }
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
    let rates: [CurrencyRate]
    let lastUpdated: String
}

// MARK: - Провайдер для виджета

struct Provider: TimelineProvider {
    // Заполнитель для предварительного просмотра
    func placeholder(in context: Context) -> CurrencyEntry {
        CurrencyEntry(
            date: Date(),
            rates: [
                CurrencyRate(code: "USD", name: "Доллар США", rate: 85.57),
                CurrencyRate(code: "EUR", name: "Евро", rate: 93.61),
                CurrencyRate(code: "TRY", name: "Турецкая лира", rate: 2.65),
                CurrencyRate(code: "AED", name: "Дирхам ОАЭ", rate: 23.30)
            ],
            lastUpdated: "14.03.2025, 10:00"
        )
    }
    
    // Снимок для галереи виджетов
    func getSnapshot(in context: Context, completion: @escaping (CurrencyEntry) -> Void) {
        let entry = CurrencyEntry(
            date: Date(),
            rates: [
                CurrencyRate(code: "USD", name: "Доллар США", rate: 85.57),
                CurrencyRate(code: "EUR", name: "Евро", rate: 93.61),
                CurrencyRate(code: "TRY", name: "Турецкая лира", rate: 2.65),
                CurrencyRate(code: "AED", name: "Дирхам ОАЭ", rate: 23.30)
            ],
            lastUpdated: "14.03.2025, 10:00"
        )
        completion(entry)
    }
    
    // Таймлайн для обновления виджета
    func getTimeline(in context: Context, completion: @escaping (Timeline<CurrencyEntry>) -> Void) {
        // Запрос к API ЦБ РФ
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else {
            let entry = createBackupEntry()
            let timeline = Timeline(entries: [entry], policy: .after(Calendar.current.date(byAdding: .hour, value: 1, to: Date())!))
            completion(timeline)
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            // Обработка ошибок или отсутствия данных
            guard let data = data, error == nil else {
                let entry = createBackupEntry()
                let timeline = Timeline(entries: [entry], policy: .after(Calendar.current.date(byAdding: .hour, value: 1, to: Date())!))
                completion(timeline)
                return
            }
            
            // Декодирование JSON-ответа
            do {
                let cbrResponse = try JSONDecoder().decode(CBRResponse.self, from: data)
                
                // Массив для хранения курсов валют
                var rates: [CurrencyRate] = []
                
                // Добавляем доллар, евро, лиру и дирхам
                if let usdData = cbrResponse.Valute["USD"] {
                    let usdRate = usdData.Value / Double(usdData.Nominal)
                    rates.append(CurrencyRate(code: "USD", name: "Доллар США", rate: usdRate))
                }
                
                if let eurData = cbrResponse.Valute["EUR"] {
                    let eurRate = eurData.Value / Double(eurData.Nominal)
                    rates.append(CurrencyRate(code: "EUR", name: "Евро", rate: eurRate))
                }
                
                if let tryData = cbrResponse.Valute["TRY"] {
                    let tryRate = tryData.Value / Double(tryData.Nominal)
                    rates.append(CurrencyRate(code: "TRY", name: "Турецкая лира", rate: tryRate))
                }
                
                if let aedData = cbrResponse.Valute["AED"] {
                    let aedRate = aedData.Value / Double(aedData.Nominal)
                    rates.append(CurrencyRate(code: "AED", name: "Дирхам ОАЭ", rate: aedRate))
                }
                
                // Форматирование даты обновления
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "dd.MM.yyyy, HH:mm"
                let lastUpdated = dateFormatter.string(from: Date())
                
                // Создание записи для таймлайна
                let entry = CurrencyEntry(
                    date: Date(),
                    rates: rates,
                    lastUpdated: lastUpdated
                )
                
                // Создание таймлайна с обновлением через 1 час
                let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date())!
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                
                completion(timeline)
                
            } catch {
                let entry = createBackupEntry()
                let timeline = Timeline(entries: [entry], policy: .after(Calendar.current.date(byAdding: .hour, value: 1, to: Date())!))
                completion(timeline)
            }
        }
        
        task.resume()
    }
    
    // Функция для создания резервной записи
    private func createBackupEntry() -> CurrencyEntry {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd.MM.yyyy, HH:mm"
        
        return CurrencyEntry(
            date: Date(),
            rates: [
                CurrencyRate(code: "USD", name: "Доллар США", rate: 85.57),
                CurrencyRate(code: "EUR", name: "Евро", rate: 93.61),
                CurrencyRate(code: "TRY", name: "Турецкая лира", rate: 2.65),
                CurrencyRate(code: "AED", name: "Дирхам ОАЭ", rate: 23.30)
            ],
            lastUpdated: "\(dateFormatter.string(from: Date())) (резерв)"
        )
    }
}

// MARK: - Представления виджета

// Компактная ячейка для отображения валюты
struct CurrencyGridCell: View {
    var rate: CurrencyRate
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
            
            Text(String(format: "%.2f ₽", rate.rate))
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(colorScheme == .dark ? Color(red: 0.1, green: 0.15, blue: 0.25) : Color(red: 0.9, green: 0.95, blue: 1.0))
        .cornerRadius(8)
    }
}

// Виджет в маленьком размере (показывает доллар и евро)
struct CurrencyWidgetSmallView: View {
    var entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    
    // Функция для получения USD и EUR валют
    private func getMainCurrencies() -> [CurrencyRate] {
        let mainCodes = ["USD", "EUR"]
        let mainRates = entry.rates.filter { mainCodes.contains($0.code) }
            .sorted { mainCodes.firstIndex(of: $0.code)! < mainCodes.firstIndex(of: $1.code)! }
        return mainRates
    }
    
    var body: some View {
        VStack(spacing: 8) {
            let currencies = getMainCurrencies()
            
            // Сетка валют 2x1
            VStack(spacing: 8) {
                ForEach(currencies, id: \.code) { rate in
                    CurrencyGridCell(rate: rate)
                }
            }
            .padding(.horizontal, 8)
            .padding(.top, 2)
            
            Spacer()
            
            // Подвал
            HStack {
                Spacer()
                Text("Converter")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 5)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// Виджет среднего размера - обновленная версия с сеткой 2x2
struct CurrencyWidgetMediumView: View {
    var entry: Provider.Entry
    @Environment(\.colorScheme) var colorScheme
    
    // Функция для разделения валют на две строки
    private func currencyRows() -> [[CurrencyRate]] {
        // Определяем фиксированный порядок валют: USD, EUR, TRY, AED
        let orderedCodes = ["USD", "EUR", "TRY", "AED"]
        
        // Создаем упорядоченный массив по заданному порядку
        var orderedRates: [CurrencyRate] = []
        for code in orderedCodes {
            if let rate = entry.rates.first(where: { $0.code == code }) {
                orderedRates.append(rate)
            }
        }
        
        // Добавляем любые оставшиеся валюты, которые не были в orderedCodes
        for rate in entry.rates {
            if !orderedCodes.contains(rate.code) && !orderedRates.contains(where: { $0.code == rate.code }) {
                orderedRates.append(rate)
            }
        }
        
        // Разделяем на две строки
        let firstRow = Array(orderedRates.prefix(2))  // USD, EUR
        let secondRow = Array(orderedRates.dropFirst(2).prefix(2))  // TRY, AED
        
        return [firstRow, secondRow]
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Сетка валют 2x2
            VStack(spacing: 8) {
                ForEach(currencyRows(), id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(row, id: \.code) { rate in
                            CurrencyGridCell(rate: rate)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.top, 2)
            
            Spacer()
            
            // Подвал
            HStack {
                Spacer()
                Text("Converter")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.bottom, 5)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

// MARK: - Основная конфигурация виджета

struct CurrencyWidget: Widget {
    let kind: String = "CurrencyWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
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
        .configurationDisplayName("Курс валют")
        .description("Отображает текущий курс основных валют к рублю.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Превью виджетов

struct CurrencyWidget_Previews: PreviewProvider {
    static var previews: some View {
        let sampleEntry = CurrencyEntry(
            date: Date(),
            rates: [
                CurrencyRate(code: "USD", name: "Доллар США", rate: 85.57),
                CurrencyRate(code: "EUR", name: "Евро", rate: 93.61),
                CurrencyRate(code: "TRY", name: "Турецкая лира", rate: 2.65),
                CurrencyRate(code: "AED", name: "Дирхам ОАЭ", rate: 23.30)
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
