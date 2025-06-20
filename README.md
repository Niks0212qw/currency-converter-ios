# Currency Converter iOS

Приложение для конвертации валют на iOS и iPadOS с функциональностью калькулятора.

## 📱 Особенности

- 🌍 Поддержка 13 популярных валют
- 📊 Актуальные курсы валют из ЦБ РФ и ExchangeRate API
- 🧮 Встроенный калькулятор
- 📱 Адаптивный интерфейс для iPhone и iPad
- 🔄 Автоматическое обновление курсов
- 🎨 Поддержка светлой и темной темы
- 📊 Виджеты для домашнего экрана
- ⌨️ Удобный ввод с экранной клавиатуры

## 🌍 Поддерживаемые валюты

- 🇷🇺 Российский рубль (RUB)
- 🇺🇸 Доллар США (USD)
- 🇪🇺 Евро (EUR)
- 🇹🇷 Турецкая лира (TRY)
- 🇰🇿 Казахский тенге (KZT)
- 🇨🇳 Китайский юань (CNY)
- 🇦🇪 Дирхам ОАЭ (AED)
- 🇺🇿 Узбекский сум (UZS)
- 🇧🇾 Белорусский рубль (BYN)
- 🇹🇭 Таиландский бат (THB)
- 🇺🇦 Украинская гривна (UAH)
- 🇬🇧 Британский фунт (GBP)
- 🇯🇵 Японская йена (JPY)

## 📸 Скриншоты

### Главная страница
<img src= "https://github.com/user-attachments/assets/54be38d4-42ee-46ff-8832-55a8b1b02d5b" width = "325">

### Страница с выбором валют
<img src= "https://github.com/user-attachments/assets/8c9edc2f-53d9-467d-ab72-656bd1046f3f" width = "325">

### Виджеты приложения на рабочем столе
<img src= "https://github.com/user-attachments/assets/8baf21b0-1644-4dd4-97f8-5cacaf82dcae" width = "325">

## 📥 Установка

### Через TestFlight
*Скоро будет доступно*

### Сборка из исходного кода

#### Системные требования
- **Для разработки:**
  - macOS 13.0 или выше
  - Xcode 15.0 или выше
  - iOS Deployment Target: 16.0+

- **Для использования:**
  - iPhone: iOS 16.0 или выше
  - iPad: iPadOS 16.0 или выше

#### Инструкции по сборке

1. **Клонируйте репозиторий:**
```bash
git clone https://github.com/Niks0212qw/currency-converter-ios.git
cd currency-converter-ios
```

2. **Откройте проект в Xcode:**
```bash
open CurrencyConverter.xcodeproj
```

3. **Настройте подпись:**
   - Выберите ваш Apple ID в **Signing & Capabilities**
   - Измените **Bundle Identifier** на уникальный

4. **Соберите и запустите:**
   - Выберите целевое устройство или симулятор
   - Нажмите ⌘+R для сборки и запуска

## 📊 Виджеты

Приложение включает виджеты для домашнего экрана:

### Маленький виджет
- Отображает курсы USD и EUR
- Компактный размер для быстрого просмотра

### Средний виджет
- Показывает 4 основные валюты: USD, EUR, TRY, AED
- Сетка 2×2 для удобного восприятия

## 🔧 Использование

### Основные функции
- **Конвертация валют**: Выберите исходную и целевую валюту, введите сумму
- **Калькулятор**: Выполняйте вычисления перед конвертацией
- **Смена валют**: Нажмите кнопку со стрелками для быстрой смены
- **Обновление курсов**: Потяните вниз для обновления или нажмите кнопку обновления

### Навигация
- **Выбор валют**: Нажмите на блок валюты для открытия списка
- **Поиск валют**: Используйте поиск для быстрого нахождения нужной валюты
- **Виджеты**: Добавьте виджеты на домашний экран для быстрого доступа к курсам

## 🏗 Архитектура

### Технологии
- **SwiftUI** - современный пользовательский интерфейс
- **Combine** - реактивное программирование
- **WidgetKit** - виджеты для домашнего экрана
- **URLSession** - сетевые запросы
- **UserDefaults** - локальное хранение данных

### Структура проекта
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

### Источники данных
- **ЦБ РФ API** (`cbr-xml-daily.ru`) - курсы валют к рублю
- **ExchangeRate API** (`open.er-api.com`) - международные курсы

### Обновление данных
- Автоматическое обновление при запуске приложения
- Ручное обновление по запросу пользователя
- Кеширование данных для офлайн-работы
- Резервные курсы при отсутствии интернета

## 🐛 Ограничения

- Виджеты требуют iOS 16.0+
- Некоторые функции могут быть недоступны в симуляторе
- Курсы валют обновляются в зависимости от доступности API

## 📄 Лицензия

Этот проект распространяется под лицензией MIT. См. файл [LICENSE](LICENSE) для получения дополнительной информации.

## 👨‍💻 Автор

**Nikita Krivonosov** - nikskrivonosovv@gmail.com
