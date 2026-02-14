//
//  AppIntent.swift
//  CurrencyWidgetExtension
//
//  Created by Никита Кривоносов on 14.03.2025.
//

import WidgetKit
import AppIntents

enum CurrencyCode: String, AppEnum, CaseIterable {
    case rub = "RUB"
    case usd = "USD"
    case eur = "EUR"
    case tryCode = "TRY"
    case kzt = "KZT"
    case cny = "CNY"
    case aed = "AED"
    case uzs = "UZS"
    case byn = "BYN"
    case thb = "THB"
    case uah = "UAH"
    case gbp = "GBP"
    case jpy = "JPY"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Валюта")
    }
    
    static var caseDisplayRepresentations: [CurrencyCode: DisplayRepresentation] {
        [
            .rub: DisplayRepresentation(title: "RUB — Российский рубль"),
            .usd: DisplayRepresentation(title: "USD — Доллар США"),
            .eur: DisplayRepresentation(title: "EUR — Евро"),
            .tryCode: DisplayRepresentation(title: "TRY — Турецкая лира"),
            .kzt: DisplayRepresentation(title: "KZT — Казахский тенге"),
            .cny: DisplayRepresentation(title: "CNY — Китайский юань"),
            .aed: DisplayRepresentation(title: "AED — Дирхам ОАЭ"),
            .uzs: DisplayRepresentation(title: "UZS — Узбекский сум"),
            .byn: DisplayRepresentation(title: "BYN — Белорусский рубль"),
            .thb: DisplayRepresentation(title: "THB — Таиландский бат"),
            .uah: DisplayRepresentation(title: "UAH — Украинская гривна"),
            .gbp: DisplayRepresentation(title: "GBP — Британский фунт"),
            .jpy: DisplayRepresentation(title: "JPY — Японская йена")
        ]
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "Настройки виджета" }
    static var description: IntentDescription { "Выберите базовую валюту и валюты для отображения." }
    
    static let defaultCurrencies: [CurrencyCode] = [.usd, .eur, .cny, .tryCode, .kzt]

    @Parameter(title: "Базовая валюта", default: .rub)
    var baseCurrency: CurrencyCode
    
    @Parameter(title: "Валюты", default: [.usd, .eur, .cny, .tryCode, .kzt])
    var currencies: [CurrencyCode]
}
