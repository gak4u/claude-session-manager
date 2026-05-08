import SwiftUI

struct SessionCardView: View {
    let session: Session
    let onResume: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            VStack(alignment: .leading, spacing: 1) {
                Text(session.displayPath)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(session.shortID)
                    .font(.system(size: 11, design: .monospaced))
                Text(RelativeTime.format(session.savedAt))
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 11))

            HStack(spacing: 6) {
                Button("Resume", action: onResume)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.orange)
                Button("Rename", action: onRename)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                Button(role: .destructive, action: onDelete) {
                    Text("Delete")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ActiveCardView: View {
    let session: ActiveSession
    let onSaveAs: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(session.projectName)
                    .font(.system(size: 14, weight: .semibold))
                Text("LIVE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.orange)
                    .tracking(0.5)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(session.displayPath)
                    .font(.system(size: 11, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(session.shortID)
                    .font(.system(size: 11, design: .monospaced))
                Text("active " + RelativeTime.format(session.lastActive))
            }
            .foregroundStyle(.secondary)
            .font(.system(size: 11))

            Button("Save as…", action: onSaveAs)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

enum RelativeTime {
    static func format(_ date: Date) -> String {
        let s = Int(Date().timeIntervalSince(date))
        if s < 60 { return "\(s)s ago" }
        if s < 3600 { return "\(s / 60)m ago" }
        if s < 86400 { return "\(s / 3600)h ago" }
        return "\(s / 86400)d ago"
    }
}
