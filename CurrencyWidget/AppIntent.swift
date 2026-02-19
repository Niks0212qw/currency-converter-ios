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
    case amd = "AMD"
    case gel = "GEL"
    case aud = "AUD"
    case cad = "CAD"
    case chf = "CHF"
    case krw = "KRW"
    case nzd = "NZD"
    case sek = "SEK"
    case nok = "NOK"
    case dkk = "DKK"
    case pln = "PLN"
    case azn = "AZN"
    case dzd = "DZD"
    case brl = "BRL"
    case inr = "INR"
    case kgs = "KGS"
    case tjs = "TJS"
    case rsd = "RSD"
    case czk = "CZK"
    case ron = "RON"
    case mdl = "MDL"
    case egp = "EGP"
    case qar = "QAR"
    case cup = "CUP"
    
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
            .jpy: DisplayRepresentation(title: "intent.currency.jpy"),
            .amd: DisplayRepresentation(title: "intent.currency.amd"),
            .gel: DisplayRepresentation(title: "intent.currency.gel"),
            .aud: DisplayRepresentation(title: "intent.currency.aud"),
            .cad: DisplayRepresentation(title: "intent.currency.cad"),
            .chf: DisplayRepresentation(title: "intent.currency.chf"),
            .krw: DisplayRepresentation(title: "intent.currency.krw"),
            .nzd: DisplayRepresentation(title: "intent.currency.nzd"),
            .sek: DisplayRepresentation(title: "intent.currency.sek"),
            .nok: DisplayRepresentation(title: "intent.currency.nok"),
            .dkk: DisplayRepresentation(title: "intent.currency.dkk"),
            .pln: DisplayRepresentation(title: "intent.currency.pln"),
            .azn: DisplayRepresentation(title: "intent.currency.azn"),
            .dzd: DisplayRepresentation(title: "intent.currency.dzd"),
            .brl: DisplayRepresentation(title: "intent.currency.brl"),
            .inr: DisplayRepresentation(title: "intent.currency.inr"),
            .kgs: DisplayRepresentation(title: "intent.currency.kgs"),
            .tjs: DisplayRepresentation(title: "intent.currency.tjs"),
            .rsd: DisplayRepresentation(title: "intent.currency.rsd"),
            .czk: DisplayRepresentation(title: "intent.currency.czk"),
            .ron: DisplayRepresentation(title: "intent.currency.ron"),
            .mdl: DisplayRepresentation(title: "intent.currency.mdl"),
            .egp: DisplayRepresentation(title: "intent.currency.egp"),
            .qar: DisplayRepresentation(title: "intent.currency.qar"),
            .cup: DisplayRepresentation(title: "intent.currency.cup")
        ]
    }
}

enum WidgetRateSource: String, AppEnum, CaseIterable {
    case exchangeRate = "exchange_rate"
    case cbr = "cbr"
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "intent.source.type")
    }
    
    static var caseDisplayRepresentations: [WidgetRateSource: DisplayRepresentation] {
        [
            .exchangeRate: DisplayRepresentation(title: "intent.source.exchange_rate"),
            .cbr: DisplayRepresentation(title: "intent.source.cbr")
        ]
    }
}

struct RateSourceOptionsProvider: DynamicOptionsProvider {
    @IntentParameterDependency<ConfigurationAppIntent>(\.$baseCurrency)
    var intent
    
    func results() async throws -> [WidgetRateSource] {
        let base = intent?.baseCurrency ?? .rub
        let selected = intent?.currencies ?? ConfigurationAppIntent.defaultCurrencies
        let hasRublePair = base == .rub || selected.contains(.rub)
        return hasRublePair ? [.exchangeRate, .cbr] : [.exchangeRate]
    }
}

struct ConfigurationAppIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource { "intent.config.title" }
    static var description: IntentDescription { "intent.config.description" }
    
    static let defaultCurrencies: [CurrencyCode] = [.usd, .eur, .cny, .tryCode, .kzt]

    @Parameter(title: "intent.base_currency", default: .rub)
    var baseCurrency: CurrencyCode
    
    @Parameter(title: "intent.source", default: .exchangeRate, optionsProvider: RateSourceOptionsProvider())
    var rateSource: WidgetRateSource
    
    @Parameter(title: "intent.currencies", default: [.usd, .eur, .cny, .tryCode, .kzt])
    var currencies: [CurrencyCode]
}
