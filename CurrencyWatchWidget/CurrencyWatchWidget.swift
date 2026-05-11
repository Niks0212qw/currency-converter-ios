import WidgetKit
import SwiftUI

private struct WatchWidgetCBRResponse: Decodable {
    let Valute: [String: CBRCurrency]

    struct CBRCurrency: Decodable {
        let Nominal: Int
        let Value: Double
    }
}

private struct WatchWidgetRate: Hashable {
    let code: String
    let flag: String
    let rubPrice: Double
}

private struct WatchWidgetEntry: TimelineEntry {
    let date: Date
    let rates: [WatchWidgetRate]
}

private struct WatchWidgetProvider: TimelineProvider {
    private static let targetCurrencies: [(code: String, flag: String)] = [
        ("USD", "🇺🇸"),
        ("EUR", "🇪🇺"),
        ("GBP", "🇬🇧"),
        ("TRY", "🇹🇷")
    ]

    private static let fallbackRubPrices: [String: Double] = [
        "USD": 85.49,
        "EUR": 92.92,
        "GBP": 109.60,
        "TRY": 2.63
    ]

    private static let cbrRatesCacheKey = "CurrencyWatchWidget.cbr.fixedRates"

    func placeholder(in context: Context) -> WatchWidgetEntry {
        WatchWidgetEntry(date: Date(), rates: Self.fallbackRates())
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchWidgetEntry) -> Void) {
        completion(WatchWidgetEntry(date: Date(), rates: Self.fallbackRates()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchWidgetEntry>) -> Void) {
        Task {
            let rates = await fetchCBRRatesWithTimeout() ?? Self.cachedRates() ?? Self.fallbackRates()
            let entry = WatchWidgetEntry(date: Date(), rates: rates)
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
            completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
        }
    }

    static func fallbackRates() -> [WatchWidgetRate] {
        targetCurrencies.map { currency in
            WatchWidgetRate(
                code: currency.code,
                flag: currency.flag,
                rubPrice: fallbackRubPrices[currency.code] ?? 0
            )
        }
    }

    private static func cachedRates() -> [WatchWidgetRate]? {
        guard let cached = UserDefaults.standard.dictionary(forKey: cbrRatesCacheKey) as? [String: Double] else {
            return nil
        }
        return rates(from: cached)
    }

    private static func rates(from rubPrices: [String: Double]) -> [WatchWidgetRate] {
        targetCurrencies.map { currency in
            WatchWidgetRate(
                code: currency.code,
                flag: currency.flag,
                rubPrice: rubPrices[currency.code] ?? fallbackRubPrices[currency.code] ?? 0
            )
        }
    }

    private func fetchCBRRatesWithTimeout() async -> [WatchWidgetRate]? {
        await withTaskGroup(of: [WatchWidgetRate]?.self) { group in
            group.addTask {
                await fetchCBRRates()
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                return nil
            }

            let result = await group.next() ?? nil
            group.cancelAll()
            return result
        }
    }

    private func fetchCBRRates() async -> [WatchWidgetRate]? {
        guard let url = URL(string: "https://www.cbr-xml-daily.ru/daily_json.js") else {
            return nil
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                return nil
            }

            let decoded = try JSONDecoder().decode(WatchWidgetCBRResponse.self, from: data)
            var rubPrices: [String: Double] = [:]
            for (code, currency) in decoded.Valute {
                rubPrices[code] = currency.Value / Double(currency.Nominal)
            }

            UserDefaults.standard.set(rubPrices, forKey: Self.cbrRatesCacheKey)
            return Self.rates(from: rubPrices)
        } catch {
            return nil
        }
    }
}

private struct CurrencyWatchWidgetView: View {
    let entry: WatchWidgetEntry

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rateRows.indices, id: \.self) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(Array(rateRows[rowIndex].enumerated()), id: \.element) { columnIndex, rate in
                        rateCell(rate)
                            .padding(.leading, columnIndex == 1 ? 5 : 0)
                    }
                }
            }
        }
        .padding(.horizontal, 3)
        .widgetAccentable()
        .unredacted()
    }

    private var rateRows: [[WatchWidgetRate]] {
        stride(from: 0, to: entry.rates.count, by: 2).map { index in
            Array(entry.rates[index..<min(index + 2, entry.rates.count)])
        }
    }

    private func rateCell(_ rate: WatchWidgetRate) -> some View {
        HStack(spacing: 3) {
            Text(rate.flag)
                .font(.system(size: 18))
                .frame(width: 22, alignment: .leading)

            Text(rateText(rate.rubPrice))
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.62)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rateText(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = value < 10 ? 2 : 0
        return formatter.string(from: NSNumber(value: value)) ?? "0"
    }
}

struct CurrencyWatchWidget: Widget {
    let kind = "CurrencyWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchWidgetProvider()) { entry in
            CurrencyWatchWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("CoinVerter")
        .description("CBR rates for USD, EUR, GBP and TRY in rubles.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct CurrencyWatchWidget_Previews: PreviewProvider {
    static var previews: some View {
        CurrencyWatchWidgetView(
            entry: WatchWidgetEntry(
                date: Date(),
                rates: WatchWidgetProvider.fallbackRates()
            )
        )
        .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
    }
}
