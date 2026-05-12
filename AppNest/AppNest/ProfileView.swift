import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

struct ProfileView: View {
    @Query(sort: \JobApplication.dateApplied, order: .reverse) private var applications: [JobApplication]

    @State private var defaultResumeFileName: String? = nil
    @State private var defaultResumeBookmark: Data?   = nil
    @State private var isShowingDocumentPicker = false
    @State private var isShowingShareSheet     = false
    @State private var csvFileURL: URL?        = nil

    // MARK: - Computed Stats

    private var totalCount: Int { applications.count }

    private var statusCounts: [(ApplicationStatus, Int)] {
        ApplicationStatus.allCases.compactMap { status in
            let count = applications.filter { $0.status == status }.count
            return count > 0 ? (status, count) : nil
        }
    }

    private var topCompanies: [(String, Int)] {
        Dictionary(grouping: applications, by: { $0.companyName })
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
            .prefix(3)
            .map { ($0.0, $0.1) }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 18) {
                    overviewSection
                    if !topCompanies.isEmpty { topCompaniesSection }
                    resumeSection
                    exportSection
                }
                .padding()
            }
        }
        .navigationTitle("Profile")
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $isShowingDocumentPicker) {
            ProfileDocumentPicker { result in
                if case .success(let picked) = result {
                    defaultResumeFileName = picked.fileName
                    defaultResumeBookmark = picked.bookmark
                }
            }
        }
        .sheet(isPresented: $isShowingShareSheet) {
            if let url = csvFileURL { ShareSheet(activityItems: [url]) }
        }
    }

    // MARK: - Overview

    private var overviewSection: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Overview", systemImage: "chart.bar.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)
                Spacer()
            }

            VStack(spacing: 4) {
                Text("\(totalCount)")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .foregroundStyle(.accentColor)
                Text("Total Applications")
                    .font(.subheadline)
                    .foregroundStyle(DarkTheme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)

            if !statusCounts.isEmpty {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(statusCounts, id: \.0) { status, count in
                        let style = DarkTheme.statusStyle(for: status)
                        HStack(spacing: 8) {
                            Image(systemName: style.iconName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(style.tintColor)
                            Text(status.rawValue)
                                .font(.subheadline)
                                .foregroundStyle(DarkTheme.textSecondary)
                            Spacer()
                            Text("\(count)")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(style.tintColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(style.gradient)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(style.borderColor, lineWidth: 0.8)
                                )
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Top Companies

    private var topCompaniesSection: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Top Companies", systemImage: "building.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)
                Spacer()
            }

            ForEach(Array(topCompanies.enumerated()), id: \.element.0) { index, item in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(DarkTheme.textTertiary)
                        .frame(width: 20)

                    Text(item.0)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(DarkTheme.textPrimary)

                    Spacer()

                    Text("\(item.1) app\(item.1 == 1 ? "" : "s")")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DarkTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.07)))
                }
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Resume

    private var resumeSection: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Default Resume", systemImage: "doc.richtext")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)
                Spacer()
            }

            HStack(spacing: 10) {
                Image(systemName: "doc.text")
                    .foregroundStyle(.secondary)
                Text(defaultResumeFileName ?? "No file selected")
                    .foregroundStyle(defaultResumeFileName == nil ? .secondary : .primary)
                    .font(.subheadline)
                Spacer()
                if defaultResumeFileName != nil {
                    Button(role: .destructive) {
                        defaultResumeFileName = nil
                        defaultResumeBookmark = nil
                    } label: {
                        Image(systemName: "trash").foregroundStyle(.red)
                    }
                }
                Button { isShowingDocumentPicker = true } label: {
                    Image(systemName: "paperclip")
                        .foregroundStyle(.accentColor)
                        .padding(8)
                        .background(Circle().fill(Color.accentColor.opacity(0.12)))
                }
            }
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - Export

    private var exportSection: some View {
        VStack(spacing: 14) {
            HStack {
                Label("Export Data", systemImage: "square.and.arrow.up")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DarkTheme.textPrimary)
                Spacer()
            }

            Button { exportCSV() } label: {
                Label("Export as CSV", systemImage: "tablecells")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(applications.isEmpty ? .secondary : .accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background {
                        Capsule()
                            .fill(applications.isEmpty
                                  ? Color.primary.opacity(0.06)
                                  : Color.accentColor.opacity(0.12))
                            .overlay(
                                Capsule().strokeBorder(
                                    applications.isEmpty ? Color.primary.opacity(0.06) : Color.accentColor.opacity(0.25),
                                    lineWidth: 0.8
                                )
                            )
                    }
            }
            .disabled(applications.isEmpty)
        }
        .padding(18)
        .glassCard()
    }

    // MARK: - CSV Export

    private func exportCSV() {
        var csv = "Company,Position,Type,Status,Season,Date Applied,Notes\n"
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        for app in applications {
            let fields = [
                escapeCSV(app.companyName),
                escapeCSV(app.position),
                escapeCSV(app.jobType?.rawValue ?? ""),
                escapeCSV(app.status?.rawValue ?? ""),
                escapeCSV(app.season?.rawValue ?? ""),
                escapeCSV(dateFormatter.string(from: app.dateApplied)),
                escapeCSV(app.jobNotes ?? "")
            ]
            csv += fields.joined(separator: ",") + "\n"
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppNest_Export.csv")
        do {
            try csv.write(to: tempURL, atomically: true, encoding: .utf8)
            csvFileURL = tempURL
            isShowingShareSheet = true
        } catch {
            print("CSV export failed: \(error)")
        }
    }

    private func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}

// MARK: - Document Picker

private struct ProfileDocumentPicker: UIViewControllerRepresentable {
    struct PickedFile { let fileName: String; let bookmark: Data }
    var completion: (Result<PickedFile, Error>) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.pdf, .plainText, .rtf, .data], asCopy: true
        )
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let completion: (Result<PickedFile, Error>) -> Void
        init(completion: @escaping (Result<PickedFile, Error>) -> Void) { self.completion = completion }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            do {
                let _ = url.startAccessingSecurityScopedResource()
                defer { url.stopAccessingSecurityScopedResource() }
                let bookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                completion(.success(PickedFile(fileName: url.lastPathComponent, bookmark: bookmark)))
            } catch { completion(.failure(error)) }
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {}
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack { ProfileView() }
        .modelContainer(for: JobApplication.self, inMemory: true)
}
