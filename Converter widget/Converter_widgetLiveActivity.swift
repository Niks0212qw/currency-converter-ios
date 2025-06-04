struct converter_widgetliveactivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ConverterActivityAttributes.self) { context in
            // Вью, которое показывается на экране блокировки или в Dynamic Island (iPhone 14 Pro)
            VStack {
                Text("Live Activity")
                Text("Текущие курсы: \(context.state.currentRate)")
            }
            .padding()
        } dynamicIsland: { context in
            // Настройка расширенного вида для Dynamic Island
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text("Ведущий блок")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Хвостовой блок")
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Текущий курс: \(context.state.currentRate)")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Доп. инфо")
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T")
            } minimal: {
                Text("M")
            }
        }
    }
}

/// Атрибуты для Live Activity
struct ConverterActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Состояние Live Activity, например текущий курс
        var currentRate: String
    }
}
