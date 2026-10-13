import SwiftUI
import PhotosUI
#if canImport(UIKit)
import UIKit
#endif

struct JobInfoSection: View {
    @Binding var companyName: String
    @Binding var companyLogoImageData: Data?
    @Binding var logoRemoved: Bool
    @Binding var position: String
    @Binding var pickerItem: PhotosPickerItem?
    var onAutoFetchStateChanged: ((Bool) -> Void)? = nil

    private enum Field: Hashable { case company, position }
    private static let logoShape = RoundedRectangle(cornerRadius: 24, style: .continuous)
    @FocusState private var focused: Field?
    @Environment(\.colorScheme) private var colorScheme
    @State private var isFetchingLogo = false
    @State private var isLogoAutoFetched = false

    private var logoImage: Image? {
        guard let data = companyLogoImageData, let ui = UIImage(data: data) else { return nil }
        return Image(uiImage: ui)
    }

    private var hasLogo: Bool {
        guard let data = companyLogoImageData else { return false }
        return UIImage(data: data) != nil
    }

    var body: some View {
        VStack(spacing: 0) {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                ZStack {
                    // Same pastel placeholder as the job card and profile — shown until a logo loads.
                    InitialAvatar(name: companyName, fontSize: 30)
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
                // Same rounded square as the job card's 60pt / r20 avatar, scaled to 72pt.
                .clipShape(Self.logoShape)
                .background {
                    if isFetchingLogo {
                        Self.logoShape
                            .fill(Color.primary.opacity(0.12))
                    }
                }
                .overlay(
                    Self.logoShape
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
                        AppIcon("camera.fill")
                            .appFont(9, weight: .bold)
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(Theme.buttonGreen))
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
                            logoRemoved = false
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
                            logoRemoved = true
                        }
                        onAutoFetchStateChanged?(false)
                        AppHaptics.shared.light()
                    } label: {
                        AppLabel("Remove Logo", systemImage: "trash")
                    }
                }
            }
            .onChange(of: companyName) { _, _ in logoRemoved = false }
            .task(id: companyName) {
                if isLogoAutoFetched {
                    withAnimation(.appFastOut) {
                        companyLogoImageData = nil
                        isLogoAutoFetched = false
                    }
                    onAutoFetchStateChanged?(false)
                }
                guard !logoRemoved, companyLogoImageData == nil else { return }
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

            VStack(spacing: 12) {
                boxedField(.company, label: "Company", icon: "building.2", placeholder: "Company name",
                           text: $companyName, fontSize: 17, capitalization: .words, submit: .next) {
                    focused = .position
                }
                boxedField(.position, label: "Position", icon: "briefcase", placeholder: "Job title",
                           text: $position, fontSize: 17, capitalization: .words, submit: .done) {
                    focused = nil
                }
            }
            .padding(.top, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Boxed field

    /// Labelled box, same look as the parse card's `EditableFieldRow`. While editing, a long
    /// value scrolls so the cursor end stays visible (the front is cut off). Once focus leaves,
    /// the value shows from the start with "…" at the end instead.
    // ponytail: the truncated label is a Text laid over a transparent TextField — TextField
    // can't tail-truncate on its own. Hit-testing passes through, so tapping still edits.
    @ViewBuilder
    private func boxedField(_ field: Field, label: String, icon: String, placeholder: String,
                            text: Binding<String>, fontSize: CGFloat,
                            capitalization: TextInputAutocapitalization, submit: SubmitLabel,
                            onSubmit: @escaping () -> Void) -> some View {
        let isFocused = focused == field
        let isEmpty = text.wrappedValue.trimmingCharacters(in: .whitespaces).isEmpty
        VStack(alignment: .leading, spacing: 6) {
            // Label sits above the box, not inside it.
            HStack(spacing: 6) {
                AppIcon(icon)
                    .appFont(11, weight: .semibold)
                    .frame(width: 14)
                Text(label)
                    .appFont(12, weight: .medium)
                Text("*")
                    .appFont(12, weight: .bold)
                    .foregroundStyle(.orange)
            }
            .foregroundStyle(Theme.textSecondary)
            .padding(.leading, 4)

            TextField(placeholder, text: text)
                .appFont(fontSize, weight: .semibold)
                .foregroundStyle(isFocused || isEmpty ? Theme.textPrimary : .clear)
                .textInputAutocapitalization(capitalization)
                .lineLimit(1)
                .focused($focused, equals: field)
                .submitLabel(submit)
                .onSubmit(onSubmit)
                .overlay(alignment: .leading) {
                    if !isFocused && !isEmpty {
                        Text(text.wrappedValue)
                            .appFont(fontSize, weight: .semibold)
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isFocused ? Color.accentColor.opacity(0.04) : Color.primary.opacity(0.04))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isFocused ? Color.accentColor.opacity(0.5) : Color.primary.opacity(0.07),
                                              lineWidth: isFocused ? 1.5 : 1)
                        }
                }
                .contentShape(Rectangle())
                .onTapGesture { focused = field }
        }
        .animation(.appFastOut, value: isFocused)
    }
}
