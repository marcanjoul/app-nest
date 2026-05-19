import SwiftUI

/// Editor for hourly or salary compensation, including currency picker
/// and (for salary) a per-year / per-month toggle.
struct CompensationSection: View {
    @Binding var kind: CompensationKind?
    @Binding var amount: String
    @Binding var currency: Currency
    @Binding var salaryPeriod: SalaryPeriod

    @FocusState private var isAmountFocused: Bool

    private var orderedKindOptions: [CompensationKind] {
        if let selected = kind {
            return [selected] + CompensationKind.allCases.filter { $0 != selected }
        }
        return CompensationKind.allCases
    }

    private var amountAccent: Color { Color(red: 0.30, green: 0.80, blue: 0.45) }

    private var periodLabel: String {
        switch kind {
        case .hourly: return "hour"
        case .salary: return salaryPeriod == .yearly ? "year" : "month"
        case .none:   return ""
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(icon: "dollarsign.circle", title: "Compensation")

            HStack(spacing: 8) {
                Spacer(minLength: 0)
                ForEach(orderedKindOptions, id: \.self) { option in
                    SelectablePill(
                        option: option,
                        isSelected: option == kind,
                        color: amountAccent,
                        icon: option == .hourly ? "clock" : "banknote",
                        onTap: {
                            withAnimation(.appCrisp) {
                                kind = (kind == option ? nil : option)
                            }
                            AppHaptics.shared.light()
                        }
                    )
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)

            if kind != nil {
                HStack(spacing: 10) {
                    currencyMenu

                    HStack(spacing: 4) {
                        Text(currency.symbol)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                        TextField("0", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .focused($isAmountFocused)
                            .onChange(of: amount) { _, newValue in
                                amount = Self.sanitize(newValue)
                            }
                        Text("/ \(periodLabel)")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.primary.opacity(isAmountFocused ? 0.08 : 0.04))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        isAmountFocused ? amountAccent.opacity(0.55) : Color.primary.opacity(0.12),
                                        lineWidth: 1
                                    )
                            )
                    )
                    .frame(maxWidth: .infinity)
                }

                if kind == .salary {
                    HStack(spacing: 8) {
                        Spacer(minLength: 0)
                        ForEach(SalaryPeriod.allCases, id: \.self) { period in
                            SelectablePill(
                                option: period,
                                isSelected: period == salaryPeriod,
                                color: amountAccent,
                                icon: period == .yearly ? "calendar" : "calendar.day.timeline.left",
                                onTap: {
                                    withAnimation(.appCrisp) {
                                        salaryPeriod = period
                                    }
                                    AppHaptics.shared.light()
                                }
                            )
                        }
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .padding(16)
        .glassCard()
        .animation(.appSmooth, value: kind)
    }

    @ViewBuilder
    private var currencyMenu: some View {
        Menu {
            ForEach(Currency.allCases, id: \.self) { option in
                Button {
                    currency = option
                } label: {
                    HStack {
                        Text("\(option.symbol)  \(option.rawValue)")
                        if option == currency {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(currency.rawValue)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                Capsule(style: .continuous)
                    .fill(Color.primary.opacity(0.05))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    )
            )
        }
    }

    private static func sanitize(_ text: String) -> String {
        var seenDot = false
        var result = ""
        for ch in text {
            if ch.isNumber {
                result.append(ch)
            } else if ch == "." && !seenDot {
                seenDot = true
                result.append(ch)
            }
        }
        return result
    }
}
