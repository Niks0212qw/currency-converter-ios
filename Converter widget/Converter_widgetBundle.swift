import SwiftUI
import WidgetKit

@main
struct converter_widgetbundle: WidgetBundle {
    var body: some Widget {
        converter_widget()             // Обычный виджет
        converter_widgetliveactivity() // Live Activity
        // Можно добавлять и другие виджеты при необходимости
    }
}
