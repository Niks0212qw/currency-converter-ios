struct converter_widget: Widget {
    let kind = "converter_widget"
    
    var body: some WidgetConfiguration {
        // StaticConfiguration или IntentConfiguration
        // Для примера возьмём StaticConfiguration
        StaticConfiguration(kind: kind, provider: ConverterTimelineProvider()) { entry in
            converter_widgetEntryView(entry: entry)
        }
        .configurationDisplayName("Converter Widget")
        .description("Отображает базовые курсы валют.")
        // Настройте, какие размеры виджета поддерживаются
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

/// Вспомогательный таймлайн-провайдер
struct ConverterTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> ConverterEntry {
        ConverterEntry(date: Date(), data: "Загрузка...")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (ConverterEntry) -> Void) {
        let entry = ConverterEntry(date: Date(), data: "Пример данных")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<ConverterEntry>) -> Void) {
        // Здесь вы можете обратиться к converter_widgetcontrol и загрузить свежие данные.
        let control = converter_widgetcontrol()
        let fetched = control.fetchData()
        
        // Создаём единственную запись таймлайна (можно и больше).
        let entry = ConverterEntry(date: Date(), data: fetched)
        
        // Задаём политику обновления, например, через 30 минут
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

/// Структура записи (entry) для виджета
struct ConverterEntry: TimelineEntry {
    let date: Date
    let data: String
}

/// Вью, которое отображается внутри виджета
struct converter_widgetEntryView: View {
    let entry: ConverterEntry
    
    var body: some View {
        ZStack {
            Color.black
            VStack {
                Text("Курсы:")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(entry.data)
                    .foregroundColor(.yellow)
            }
        }
    }
}
