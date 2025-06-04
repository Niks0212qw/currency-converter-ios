//
//  Converter_widgetBundle.swift
//  Converter_widget
//
//  Created by Никита Кривоносов on 14.03.2025.
//

import WidgetKit
import SwiftUI

@main
struct Converter_widgetBundle: WidgetBundle {
    var body: some Widget {
        Converter_widget()
        Converter_widgetControl()
        Converter_widgetLiveActivity()
    }
}
