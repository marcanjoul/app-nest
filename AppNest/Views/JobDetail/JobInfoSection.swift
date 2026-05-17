import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct JobInfoSection: View {
    @Binding var companyName: String
    @Binding var companyLogoName: String
    @Binding var companyLogoImageData: Data?
    @Binding var position: String
    @Binding var pickerItem: PhotosPickerItem?

    private enum Field: Hashable { case position, company }
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

    #if canImport(UIKit)
    private var logoImage: Image? {
        if let data = companyLogoImageData, let ui = UIImage(data: data) {
            return Image(uiImage: ui)
        } else if !companyLogoName.isEmpty, UIImage(named: companyLogoName) != nil {
            return Image(companyLogoName)
        }
        return nil
    }
    private var hasLogo: Bool {
        if let data = companyLogoImageData, UIImage(data: data) != nil { return true }
        return !companyLogoName.isEmpty && UIImage(named: companyLogoName) != nil
    }
    #else
    private var logoImage: Image? {
        companyLogoName.isEmpty ? nil : Image(companyLogoName)
    }
    private var hasLogo: Bool { !companyLogoName.isEmpty }
    #endif

    private var logoInitial: String {
        let trimmed = companyName.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "?" }
        return String(first).uppercased()
    }

    private let titleBaseFontSize: CGFloat = 22
    private let companyBaseFontSize: CGFloat = 12

    @ViewBuilder
    private func editableFieldBackground(isFocused: Bool, tint: Color? = nil) -> some View {
        let strokeColor: Color = isFocused
            ? (tint ?? Color.accentColor).opacity(0.55)
            : Color.primary.opacity(0.12)
        Capsule(style: .continuous)
            .fill(Color.primary.opacity(isFocused ? 0.08 : 0.04))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
    }

    var body: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    // Fallback initial — dematerializes when logo lands
                    ZStack {
                        Circle()
                            .fill(accentTint)
                        Text(logoInitial)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .opacity(hasLogo ? 0 : 1)
                    .animation(.easeOut(duration: 0.25), value: hasLogo)

                    // Logo — springs in from slightly smaller, settles into place
                    if let image = logoImage {
                        image
                            .resizable()
                            .scaledToFill()
                            .transition(
                                .asymmetric(
                                    insertion: .scale(scale: 0.82).combined(with: .opacity),
                                    removal: .opacity
                                )
                            )
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.20), radius: 10, y: 5)
                // Loading veil — fades + scales in quickly, out just as fast
                .overlay {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .opacity(isFetchingLogo ? 1 : 0)
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(isFetchingLogo ? 1 : 0.7)
                        .opacity(isFetchingLogo ? 1 : 0)
                }
                .animation(.easeOut(duration: 0.15), value: isFetchingLogo)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color(UIColor.systemBackground))
                            .frame(width: 24, height: 24)
                        Image(systemName: "camera.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Circle().fill(accentTint))
                    }
                    .offset(x: 2, y: 2)
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                guard let item = newValue else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                            companyLogoImageData = data
                            isLogoAutoFetched = false
                        }
                    }
                }
            }
            .contextMenu {
                if hasLogo {
                    Button(role: .destructive) {
                        withAnimation(.easeOut(duration: 0.25)) {
                            companyLogoImageData = nil
                            isLogoAutoFetched = false
                        }
                    } label: {
                        Label("Remove Logo", systemImage: "trash")
                    }
                }
            }
            .task(id: companyName) {
                if isLogoAutoFetched {
                    withAnimation(.easeOut(duration: 0.2)) {
                        companyLogoImageData = nil
                        isLogoAutoFetched = false
                    }
                }
                guard companyLogoImageData == nil else { return }
                let trimmed = companyName.trimmingCharacters(in: .whitespaces)
                guard trimmed.count >= 2 else { isFetchingLogo = false; return }
                do { try await Task.sleep(for: .milliseconds(600)) } catch { return }
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.15)) { isFetchingLogo = true }
                if let data = await LogoFetcher.fetchLogoData(for: trimmed, darkMode: colorScheme == .dark) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.72)) {
                        companyLogoImageData = data
                        isLogoAutoFetched = true
                    }
                }
                withAnimation(.easeOut(duration: 0.2)) { isFetchingLogo = false }
            }

            VStack(spacing: 6) {
                TextField("Position Title *", text: $position)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.45)
                    .truncationMode(.tail)
                    .font(.system(size: titleBaseFontSize, weight: .bold, design: .rounded))
                    .foregroundStyle(DarkTheme.textPrimary)
                    .focused($focused, equals: .position)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(editableFieldBackground(isFocused: focused == .position))

                TextField("COMPANY NAME *", text: $companyName)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .truncationMode(.tail)
                    .font(.system(size: companyName.isEmpty ? companyBaseFontSize * 0.85 : companyBaseFontSize, weight: .medium, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(DarkTheme.textPrimary.opacity(0.6))
                    .textInputAutocapitalization(.words)
                    .focused($focused, equals: .company)
                    .frame(maxWidth: 220)
                    .padding(.horizontal, companyName.isEmpty ? 10 : 12)
                    .padding(.vertical, companyName.isEmpty ? 4 : 6)
                    .background(editableFieldBackground(isFocused: focused == .company))
            }
            .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}
