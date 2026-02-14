//
//  AppIntent.swift
//  CurrencyWidget
//
//  Created by Никита Кривоносов on 15.03.2025.
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
        TypeDisplayRepresentation(name: "intent.currency.type")
    }
    
    static var caseDisplayRepresentations: [CurrencyCode: DisplayRepresentation] {
        [
            .rub: DisplayRepresentation(title: "intent.currency.rub"),
            .usd: DisplayRepresentation(title: "intent.currency.usd"),
            .eur: DisplayRepresentation(title: "intent.currency.eur"),
            .tryCode: DisplayRepresentation(title: "intent.currency.try"),
            .kzt: DisplayRepresentation(title: "intent.currency.kzt"),
            .cny: DisplayRepresentation(title: "intent.currency.cny"),
            .aed: DisplayRepresentation(title: "intent.currency.aed"),
            .uzs: DisplayRepresentation(title: "intent.currency.uzs"),
            .byn: DisplayRepresentation(title: "intent.currency.byn"),
            .thb: DisplayRepresentation(title: "intent.currency.thb"),
            .uah: DisplayRepresentation(title: "intent.currency.uah"),
            .gbp: DisplayRepresentation(title: "intent.currency.gbp"),
            .jpy: DisplayRepresentation(title: "intent.currency.jpy")
        ]
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "intent.config.title" }
    static var description: IntentDescription { "intent.config.description" }
    
    static let defaultCurrencies: [CurrencyCode] = [.usd, .eur, .cny, .tryCode, .kzt]

    @Parameter(title: "intent.base_currency", default: .rub)
    var baseCurrency: CurrencyCode
    
    @Parameter(title: "intent.currencies", default: [.usd, .eur, .cny, .tryCode, .kzt])
    var currencies: [CurrencyCode]
}
