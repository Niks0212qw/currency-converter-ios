import Foundation

enum WidgetL10n {
    static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
    
    static func currencyName(_ code: String) -> String {
        text("currency.\(code.lowercased())")
    }
}
