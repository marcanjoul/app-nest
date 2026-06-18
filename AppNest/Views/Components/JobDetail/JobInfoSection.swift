import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct JobInfoSection: View {
    @Binding var companyName: String
    @Binding var companyLogoImageData: Data?
    @Binding var position: String
    @Binding var pickerItem: PhotosPickerItem?
    var onAutoFetchStateChanged: ((Bool) -> Void)? = nil

    private enum Field: Hashable { case company, position }
    @FocusState private var focused: Field?
    @Environment(\.colorScheme) private var colorScheme
    @State private var isFetchingLogo = false
    @State private var isLogoAutoFetched = false

    private static let tintPalette: [Color] = [
        Color(red: 0.36, green: 0.66, blue: 0.96),
        Color(red: 0.96, green: 0.73, blue: 0.28),
        Color(red: 0.30, green: 0.80, blue: 0.45),
        Color(red: 0.93, green: 0.38, blue: 0.44),
        Color(red: 0.62, green: 0.52, blue: 0.96),
        Color(red: 0.96, green: 0.52, blue: 0.62),
    ]

    private var accentTint: Color {
        let trimmed = companyName.trimmingCharacters(in: .whitespaces)
        let key = trimmed.first.map { String($0).uppercased() } ?? "AppNest"
        return Self.tintPalette[abs(key.hashValue) % Self.tintPalette.count]
    }

    private var logoImage: Image? {
        guard let data = companyLogoImageData, let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }

    private var hasLogo: Bool {
        guard let data = companyLogoImageData else { return false }
        return UIImage(data: data) != nil
    }

    private var logoInitial: String {
        let trimmed = companyName.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    var body: some View {
        VStack(spacing: 0) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    ZStack {
                        Circle()
                            .fill(accentTint)
                        Text(logoInitial)
                            .appFont(30, weight: .heavy)
                            .foregroundStyle(.white)
                    }
                    .opacity(hasLogo ? 0 : 1)
                    .animation(.appFastOut, value: hasLogo)

                    if let image = logoImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .frame(width: 72, height: 72)
                .clipShape(Circle())
                .background {
                    if isFetchingLogo {
                        Circle()
                            .fill(Color.primary.opacity(0.12))
                            .shimmer()
                    }
                }
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.20), radius: 8, y: 4)
                .opacity(isFetchingLogo ? 0.8 : 1.0)
                .animation(.appFastOut, value: isFetchingLogo)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(Theme.background)
                            .frame(width: 22, height: 22)
                        Image(systemName: "camera.fill")
                            .appFont(9, weight: .bold)
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(accentTint))
                    }
                    .offset(x: 2, y: 2)
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        withAnimation(.appSmooth) {
                            companyLogoImageData = data
                            isLogoAutoFetched = false
                        }
                        onAutoFetchStateChanged?(false)
                        AppHaptics.shared.success()
                    }
                }
            }
            .contextMenu {
                if hasLogo {
                    Button(role: .destructive) {
                        withAnimation(.appFastOut) {
                            companyLogoImageData = nil
                            isLogoAutoFetched = false
                        }
                        onAutoFetchStateChanged?(false)
                        AppHaptics.shared.light()
                    } label: {
                        Label("Remove Logo", systemImage: "trash")
                    }
                }
            }
            .task(id: companyName) {
                if isLogoAutoFetched {
                    withAnimation(.appFastOut) {
                        companyLogoImageData = nil
                        isLogoAutoFetched = false
                    }
                    onAutoFetchStateChanged?(false)
                }
                guard companyLogoImageData == nil else { return }
                let trimmed = companyName.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else { isFetchingLogo = false; return }
                do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.appFastOut) { isFetchingLogo = true }
                if let data = await LogoFetcher.fetchLogoData(for: trimmed, darkMode: colorScheme == .dark) {
                    withAnimation(.appSmooth) {
                        companyLogoImageData = data
                        isLogoAutoFetched = true
                    }
                    onAutoFetchStateChanged?(true)
                    AppHaptics.shared.light()
                }
                withAnimation(.appFastOut) { isFetchingLogo = false }
            }

            // Company name — grouped tightly with the logo (proximity)
            TextField("Company Name *", text: $companyName)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .appFont(13, weight: .semibold)
                .foregroundStyle(Theme.textSecondary)
                .textInputAutocapitalization(.words)
                .focused($focused, equals: .company)
                .submitLabel(.next)
                .onSubmit { focused = .position }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 6)
                .overlay(alignment: .bottom) {
                    Text(companyName.isEmpty ? "Company Name *" : companyName)
                        .appFont(13, weight: .semibold)
                        .lineLimit(1)
                        .fixedSize()
                        .hidden()
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(focused == .company ? Color.accentColor : Color.primary.opacity(0.10))
                                .frame(height: 1)
                                .animation(.appCrisp, value: focused == .company)
                        }
                }

            // Position title — clear visual separation from identity group above
            TextField("Position Title *", text: $position)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .appFont(24, weight: .bold)
                .foregroundStyle(Theme.textPrimary)
                .focused($focused, equals: .position)
                .submitLabel(.done)
                .onSubmit { focused = nil }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 9)
                .overlay(alignment: .bottom) {
                    Text(position.isEmpty ? "Position Title *" : position)
                        .appFont(24, weight: .bold)
                        .lineLimit(1)
                        .fixedSize()
                        .hidden()
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(focused == .position ? Color.accentColor : Color.primary.opacity(0.12))
                                .frame(height: focused == .position ? 2 : 1)
                                .animation(.appCrisp, value: focused == .position)
                        }
                }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
