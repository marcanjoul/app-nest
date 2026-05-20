import SwiftUI

// MARK: - Skeleton Components

struct ResultsCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                SkeletonBlock(width: 100, height: 18)
                Spacer()
                SkeletonBlock(width: 60, height: 14)
            }
            
            // Company Avatar & Name
            HStack(spacing: 12) {
                Spacer()
                VStack(spacing: 12) {
                    SkeletonBlock(width: 60, height: 60, cornerRadius: 16)
                    SkeletonBlock(width: 120, height: 20)
                    SkeletonBlock(width: 180, height: 16)
                }
                Spacer()
            }
            
            // Form Fields
            VStack(spacing: 12) {
                ForEach(0..<4) { _ in
                    SkeletonBlock(width: .infinity, height: 44, cornerRadius: 10)
                }
            }
            
            Divider().opacity(0.4)
            
            // Buttons
            VStack(spacing: 12) {
                SkeletonBlock(width: .infinity, height: 50, cornerRadius: 25)
                SkeletonBlock(width: .infinity, height: 50, cornerRadius: 25)
            }
        }
        .padding(18)
        .glassCard()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

struct JobCardSkeleton: View {
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            SkeletonBlock(width: 60, height: 60, cornerRadius: 16)
            
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBlock(width: 140, height: 16)
                SkeletonBlock(width: 100, height: 14)
                
                HStack(spacing: 6) {
                    SkeletonBlock(width: 60, height: 20, cornerRadius: 10)
                    SkeletonBlock(width: 60, height: 20, cornerRadius: 10)
                }
            }
            
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.cardFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Base Skeleton Block

struct SkeletonBlock: View {
    var width: CGFloat? = nil
    var height: CGFloat
    var cornerRadius: CGFloat = 4
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.primary.opacity(0.08))
            .frame(width: width == .infinity ? nil : width, height: height)
            .frame(maxWidth: width == .infinity ? .infinity : nil)
            .shimmer()
    }
}

#Preview {
    VStack(spacing: 20) {
        ResultsCardSkeleton()
        JobCardSkeleton()
    }
    .padding()
    .background(AmbientBackground())
}
