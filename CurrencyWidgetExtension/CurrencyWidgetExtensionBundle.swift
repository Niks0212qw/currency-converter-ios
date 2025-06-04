//
//  CurrencyWidgetExtensionBundle.swift
//  CurrencyWidgetExtension
//
//  Created by Никита Кривоносов on 14.03.2025.
//

import WidgetKit
import SwiftUI

@main
struct CurrencyWidgetExtensionBundle: WidgetBundle {
    var body: some Widget {
        CurrencyWidgetExtension()
        CurrencyWidgetExtensionControl()
        CurrencyWidgetExtensionLiveActivity()
    }
}
