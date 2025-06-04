//
//  Converter_widgetLiveActivity.swift
//  Converter_widget
//
//  Created by Никита Кривоносов on 14.03.2025.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct Converter_widgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct Converter_widgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Converter_widgetAttributes.self) { context in
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

extension Converter_widgetAttributes {
    fileprivate static var preview: Converter_widgetAttributes {
        Converter_widgetAttributes(name: "World")
    }
}

extension Converter_widgetAttributes.ContentState {
    fileprivate static var smiley: Converter_widgetAttributes.ContentState {
        Converter_widgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: Converter_widgetAttributes.ContentState {
         Converter_widgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: Converter_widgetAttributes.preview) {
   Converter_widgetLiveActivity()
} contentStates: {
    Converter_widgetAttributes.ContentState.smiley
    Converter_widgetAttributes.ContentState.starEyes
}
