import SwiftUI

/// A clean, illustrative sheet that explains the CSV import/export format.
struct CSVFormatGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        // Header Illustration
                        headerIllustration
                            .padding(.top, 10)
                        
                        // Section 1: Columns
                        VStack(alignment: .leading, spacing: 16) {
                            guideSectionLabel(icon: "tablecells.fill", title: "Supported Columns")
                            
                            VStack(alignment: .leading, spacing: 12) {
                                columnRow(name: "Company", desc: "The name of the employer (Required)", aliases: "Employer, Organization")
                                columnRow(name: "Position", desc: "The job title or role (Required)", aliases: "Job Title, Role")
                                columnRow(name: "Status", desc: "Current stage in the process", aliases: "Hiring Stage, Progress")
                                columnRow(name: "Type", desc: "Full Time, Internship, Contract, etc.", aliases: "Employment")
                                columnRow(name: "Date", desc: "When you applied (YYYY-MM-DD)", aliases: "Submission Date")
                                columnRow(name: "Compensation", desc: "Pay amount (e.g. 150k, 50/hour)", aliases: "Salary, Wage")
                                columnRow(name: "Notes", desc: "Any additional details or links", aliases: "Remarks, Description")
                            }
                        }
                        
                        // Section 2: Smart Detection
                        VStack(alignment: .leading, spacing: 14) {
                            guideSectionLabel(icon: "sparkles", title: "Smart Detection")
                            Text("AppNest is flexible. It automatically detects your column headers even if they use different names, so you don't need to reformat your existing spreadsheets.")
                                .font(.system(size: 14))
                                .foregroundStyle(DarkTheme.textSecondary)
                                .lineSpacing(4)
                        }
                        
                        // Section 3: Example
                        VStack(alignment: .leading, spacing: 16) {
                            guideSectionLabel(icon: "doc.text.fill", title: "Example Row")
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Company, Position, Status, Date")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(DarkTheme.textTertiary)
                                Text("Apple, iOS Engineer, Applied, 2026-05-18")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Color.accentColor)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.04))
                                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
                            }
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("CSV Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .bold))
                }
            }
        }
    }
    
    private var headerIllustration: some View {
        HStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 60, height: 60)
                Image(systemName: "arrow.down.doc.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Flexible Importing")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DarkTheme.textPrimary)
                Text("Bring your data from Excel, Google Sheets, or other apps.")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DarkTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    private func guideSectionLabel(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Color.accentColor)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DarkTheme.textSecondary)
                .tracking(0.5)
        }
    }
    
    private func columnRow(name: String, desc: String, aliases: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DarkTheme.textPrimary)
                Spacer()
                Text(desc)
                    .font(.system(size: 12))
                    .foregroundStyle(DarkTheme.textSecondary)
            }
            
            Text("Aliases: \(aliases)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DarkTheme.textTertiary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    CSVFormatGuideSheet()
}
