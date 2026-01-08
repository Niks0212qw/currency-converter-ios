# Currency Converter iOS

A currency conversion application for iOS and iPadOS with calculator functionality.

## 📱 Features

- 🌍 Support for 13 popular currencies
- 📊 Real-time exchange rates from Central Bank of Russia and ExchangeRate API
- 🧮 Built-in calculator
- 📱 Adaptive interface for iPhone and iPad
- 🔄 Automatic exchange rate updates
- 🎨 Light and dark theme support
- 📊 Home screen widgets
- ⌨️ Convenient input with on-screen keyboard

## 🌍 Supported Currencies

- 🇷🇺 Russian Ruble (RUB)
- 🇺🇸 US Dollar (USD)
- 🇪🇺 Euro (EUR)
- 🇹🇷 Turkish Lira (TRY)
- 🇰🇿 Kazakhstani Tenge (KZT)
- 🇨🇳 Chinese Yuan (CNY)
- 🇦🇪 UAE Dirham (AED)
- 🇺🇿 Uzbekistani Som (UZS)
- 🇧🇾 Belarusian Ruble (BYN)
- 🇹🇭 Thai Baht (THB)
- 🇺🇦 Ukrainian Hryvnia (UAH)
- 🇬🇧 British Pound (GBP)
- 🇯🇵 Japanese Yen (JPY)

## 📸 Screenshots

### Main Page
<img src= "https://github.com/user-attachments/assets/54be38d4-42ee-46ff-8832-55a8b1b02d5b" width = "325">

### Currency Selection Page
<img src= "https://github.com/user-attachments/assets/8c9edc2f-53d9-467d-ab72-656bd1046f3f" width = "325">

### App Widgets on Home Screen
<img src= "https://github.com/user-attachments/assets/8baf21b0-1644-4dd4-97f8-5cacaf82dcae" width = "325">

## 📥 Installation

### Via TestFlight
*Coming soon*

### Building from Source Code

#### System Requirements
- **For Development:**
  - macOS 13.0 or higher
  - Xcode 15.0 or higher
  - iOS Deployment Target: 16.0+

- **For Usage:**
  - iPhone: iOS 16.0 or higher
  - iPad: iPadOS 16.0 or higher

#### Build Instructions

1. **Clone the repository:**
```bash
git clone https://github.com/Niks0212qw/currency-converter-ios.git
cd currency-converter-ios
```

2. **Open the project in Xcode:**
```bash
open CurrencyConverter.xcodeproj
```

3. **Configure signing:**
   - Select your Apple ID in **Signing & Capabilities**
   - Change **Bundle Identifier** to a unique one

4. **Build and run:**
   - Select target device or simulator
   - Press ⌘+R to build and run

## 📊 Widgets

The application includes home screen widgets:

### Small Widget
- Displays USD and EUR rates
- Compact size for quick view

### Medium Widget
- Shows 4 main currencies: USD, EUR, TRY, AED
- 2×2 grid for convenient viewing

## 🔧 Usage

### Main Functions
- **Currency Conversion**: Select source and target currency, enter amount
- **Calculator**: Perform calculations before conversion
- **Currency Swap**: Tap the arrow button for quick swap
- **Rate Updates**: Pull down to refresh or tap the update button

### Navigation
- **Currency Selection**: Tap on currency block to open list
- **Currency Search**: Use search for quick finding of needed currency
- **Widgets**: Add widgets to home screen for quick access to rates

## 🏗 Architecture

### Technologies
- **SwiftUI** - modern user interface
- **Combine** - reactive programming
- **WidgetKit** - home screen widgets
- **URLSession** - network requests
- **UserDefaults** - local data storage

### Project Structure
```
CurrencyConverter/
├── App/
│   ├── CurrencyConverterApp.swift
│   └── ContentView.swift
├── Views/
│   ├── CurrencyPickerView.swift
│   ├── CurrencyView.swift
│   └── Components/
├── Models/
│   ├── CurrencyCalculatorModel.swift
│   └── Currency.swift
├── Widgets/
│   ├── CurrencyWidget.swift
│   └── CurrencyWidgetLiveActivity.swift
└── Resources/
    └── Assets.xcassets
```

## 🌐 API

### Data Sources
- **Central Bank of Russia API** (`cbr-xml-daily.ru`) - currency rates to ruble
- **ExchangeRate API** (`open.er-api.com`) - international rates

### Data Updates
- Automatic update on app launch
- Manual update on user request
- Data caching for offline operation
- Fallback rates when no internet connection

## 🐛 Limitations

- Widgets require iOS 16.0+
- Some features may be unavailable in simulator
- Currency rates update depending on API availability

## 📄 License

This project is distributed under the MIT License. See the [LICENSE](LICENSE) file for more information.

## 👨‍💻 Author

**Nikita Krivonosov** - nikskrivonosovv@gmail.com
