import ActivityKit
import SwiftUI
import WidgetKit

private let nurioBlue = Color(red: 0x2F / 255, green: 0x6B / 255, blue: 0xFF / 255)
private let groupSymbol = "person.3.fill"
private let waitingText = "Waiting for your group"

struct EventGroupLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: EventGroupAttributes.self) { context in
            LockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(nil)
                .activitySystemActionForegroundColor(nurioBlue)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: groupSymbol)
                        .font(.title2)
                        .foregroundStyle(nurioBlue)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 2) {
                        Text(context.state.groupName ?? waitingText)
                            .font(.headline)
                            .lineLimit(1)
                        Text(context.attributes.eventTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let topic = context.state.topic, !topic.isEmpty {
                        Text(topic)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    }
                }
            } compactLeading: {
                Image(systemName: groupSymbol)
                    .foregroundStyle(nurioBlue)
            } compactTrailing: {
                Text(context.state.groupName ?? "…")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 64)
            } minimal: {
                Image(systemName: groupSymbol)
                    .foregroundStyle(nurioBlue)
            }
            .keylineTint(nurioBlue)
        }
    }
}

private struct LockScreenView: View {
    let attributes: EventGroupAttributes
    let state: EventGroupAttributes.ContentState

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: groupSymbol)
                .font(.title)
                .foregroundStyle(nurioBlue)

            VStack(alignment: .leading, spacing: 4) {
                Text(attributes.eventTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let groupName = state.groupName, !groupName.isEmpty {
                    Text(groupName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text(waitingText)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

                if let topic = state.topic, !topic.isEmpty {
                    Text(topic)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }
}
