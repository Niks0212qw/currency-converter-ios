//
//  CurrencyWidgetExtensionLiveActivity.swift
//  CurrencyWidgetExtension
//
//  Created by Никита Кривоносов on 14.03.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct CurrencyWidgetExtensionAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct CurrencyWidgetExtensionLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: CurrencyWidgetExtensionAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension CurrencyWidgetExtensionAttributes {
    fileprivate static var preview: CurrencyWidgetExtensionAttributes {
        CurrencyWidgetExtensionAttributes(name: "World")
    }
}

extension CurrencyWidgetExtensionAttributes.ContentState {
    fileprivate static var smiley: CurrencyWidgetExtensionAttributes.ContentState {
        CurrencyWidgetExtensionAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: CurrencyWidgetExtensionAttributes.ContentState {
         CurrencyWidgetExtensionAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: CurrencyWidgetExtensionAttributes.preview) {
   CurrencyWidgetExtensionLiveActivity()
} contentStates: {
    CurrencyWidgetExtensionAttributes.ContentState.smiley
    CurrencyWidgetExtensionAttributes.ContentState.starEyes
}
