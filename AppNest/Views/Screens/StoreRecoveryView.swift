import SwiftUI

/// Shown instead of the app when the store can't be opened.
///
/// The alternative — starting on an empty store — is what makes this kind of failure so
/// expensive: an empty list looks exactly like a wiped database, so the user deletes and
/// reinstalls, and that really does destroy the data that was still sitting on disk.
struct StoreRecoveryView: View {
    let error: Error
    let brokenStoreURL: URL?

    @State private var snapshots = StoreBackup.available()
    @State private var restored: StoreBackup.Snapshot?
    @State private var restoreError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let restored {
                    banner(
                        icon: "checkmark.circle.fill",
                        tint: .green,
                        title: "Restored from \(restored.displayName)",
                        message: "Quit App Nest completely and open it again to finish."
                    )
                } else if snapshots.isEmpty {
                    banner(
                        icon: "exclamationmark.triangle.fill",
                        tint: .orange,
                        title: "No backups available",
                        message: "Your data hasn't been deleted — it's still on this device, just unreadable by this version of the app."
                    )
                } else {
                    Text("Restore a backup")
                        .appFont(.body, weight: .semibold)
                        .foregroundStyle(Theme.textPrimary)

                    ForEach(snapshots) { snapshot in
                        Button { restore(snapshot) } label: { row(snapshot) }
                            .buttonStyle(.plain)
                    }
                }

                if let restoreError {
                    Text(restoreError)
                        .appFont(.footnote, weight: .medium)
                        .foregroundStyle(Theme.destructive)
                }

                details
            }
            .padding(20)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            AppIcon("exclamationmark.triangle.fill")
                .appFont(34, weight: .bold)
                .foregroundStyle(.orange)

            Text("Couldn't open your data")
                .appFont(.title, weight: .bold)
                .foregroundStyle(Theme.textPrimary)

            Text("Your applications are safe on this device. Don't delete the app — that would erase them for good.")
                .appFont(.body, weight: .medium)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func row(_ snapshot: StoreBackup.Snapshot) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.displayName)
                    .appFont(.body, weight: .semibold)
                    .foregroundStyle(Theme.textPrimary)
                Text(snapshot.displaySize)
                    .appFont(.footnote, weight: .medium)
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Text("Restore")
                .appFont(.body, weight: .bold)
                .foregroundStyle(Theme.accent)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface()
    }

    private func banner(icon: String, tint: Color, title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            AppLabel(title, systemImage: icon)
                .appFont(.body, weight: .semibold)
                .foregroundStyle(tint)
            Text(message)
                .appFont(.footnote, weight: .medium)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .surface()
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Technical details")
                .appFont(.footnote, weight: .semibold)
                .foregroundStyle(Theme.textTertiary)
            Text(error.localizedDescription)
                .appFont(.caption, weight: .regular)
                .foregroundStyle(Theme.textTertiary)
            if let brokenStoreURL {
                Text("Unreadable store kept at: \(brokenStoreURL.lastPathComponent)")
                    .appFont(.caption, weight: .regular)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(.top, 8)
    }

    private func restore(_ snapshot: StoreBackup.Snapshot) {
        do {
            try StoreBackup.restore(snapshot)
            restored = snapshot
            restoreError = nil
        } catch {
            restoreError = "Restore failed: \(error.localizedDescription)"
        }
    }
}
