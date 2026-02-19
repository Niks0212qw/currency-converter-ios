import SwiftUI

struct CurrencyPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedCurrency: Currency
    @State private var searchText = ""
    @EnvironmentObject var model: CurrencyCalculatorModel
    var availableCurrencies: [Currency]
    var title: String
    var onCurrencySelected: (Currency) -> Void

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private var filteredCurrencies: [Currency] {
        if searchText.isEmpty {
            return availableCurrencies
        }

        return availableCurrencies.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            PickerLiquidBackground()

            VStack(spacing: isPad ? 14 : 10) {
                CustomSearchBar(text: $searchText)
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: isPad ? 12 : 8) {
                        ForEach(filteredCurrencies, id: \.code) { currency in
                            Button {
                                selectedCurrency = currency
                                onCurrencySelected(currency)
                                dismiss()
                            } label: {
                                CurrencyRowView(currency: currency)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, isPad ? 20 : 12)
                    .padding(.bottom, isPad ? 20 : 12)
                }
            }
            .frame(maxWidth: isPad ? 640 : .infinity)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarTitle(title, displayMode: .inline)
    }
}

struct CurrencyRowView: View {
    @EnvironmentObject var model: CurrencyCalculatorModel
    var currency: Currency

    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    private static let rateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        return formatter
    }()

    var body: some View {
        HStack(spacing: isPad ? 18 : 12) {
            CurrencyCompactFlagView(currency: currency, emojiSize: isPad ? 34 : 24)
                .frame(width: isPad ? 58 : 42, height: isPad ? 58 : 42)

            VStack(alignment: .leading, spacing: 4) {
                Text(currency.name)
                    .font(isPad ? .system(size: 20, weight: .regular) : .body)
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(getCurrencyRate())
                    .font(isPad ? .system(size: 15, weight: .regular) : .caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)
            }

            Spacer()

            Text(currency.code)
                .foregroundColor(.white.opacity(0.75))
                .font(isPad ? .system(size: 20, weight: .semibold) : .callout.weight(.semibold))
        }
        .padding(.horizontal, isPad ? 18 : 12)
        .padding(.vertical, isPad ? 15 : 10)
        .background(
            Color.white.opacity(0.08),
            in: RoundedRectangle(cornerRadius: isPad ? 22 : 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: isPad ? 22 : 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
        )
    }

    private func getCurrencyRate() -> String {
        let formatter = Self.rateFormatter

        if currency.code == "RUB" {
            guard let usdRate = model.cbrRates["USD"] else {
                return AppL10n.text("no_data")
            }
            if let formattedRate = formatter.string(from: NSNumber(value: usdRate)) {
                return "1 USD = \(formattedRate) \(currency.code)"
            }
        } else {
            guard let usdRate = model.exchangeRates["USD"],
                  let currencyRate = model.exchangeRates[currency.code] else {
                return AppL10n.text("no_data")
            }
            let rate = currencyRate / usdRate
            if let formattedRate = formatter.string(from: NSNumber(value: rate)) {
                return "1 USD = \(formattedRate) \(currency.code)"
            }
        }

        return AppL10n.text("no_data")
    }
}

struct CurrencyCompactFlagView: View {
    var currency: Currency
    var emojiSize: CGFloat = 19

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )

            Text(currency.flagEmoji)
                .font(.system(size: emojiSize))
        }
    }
}

struct PickerLiquidBackground: View {
    var body: some View {
        Color(red: 0.06, green: 0.09, blue: 0.16)
            .ignoresSafeArea()
    }
}

struct CustomSearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))

            TextField(AppL10n.text("search_placeholder"), text: $text)
                .foregroundColor(.white)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
        )
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

struct CurrencyPickerView_Previews: PreviewProvider {
    static var previews: some View {
        let model = CurrencyCalculatorModel()

        return NavigationView {
            CurrencyPickerView(
                selectedCurrency: .constant(Currency(code: "USD", name: AppL10n.currencyName("USD"), flagName: "usa")),
                availableCurrencies: [
                    Currency(code: "USD", name: AppL10n.currencyName("USD"), flagName: "usa"),
                    Currency(code: "EUR", name: AppL10n.currencyName("EUR"), flagName: "europe"),
                    Currency(code: "RUB", name: AppL10n.currencyName("RUB"), flagName: "russia")
                ],
                title: AppL10n.text("currencies_title"),
                onCurrencySelected: { _ in }
            )
            .environmentObject(model)
        }
    }
}
