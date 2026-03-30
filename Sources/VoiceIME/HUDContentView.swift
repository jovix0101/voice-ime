import SwiftUI

struct HUDContentView: View {
    @ObservedObject var viewModel: HUDViewModel

    var body: some View {
        HStack(spacing: 14) {
            waveform
                .frame(width: 44, height: 32)

            Text(viewModel.text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.96))
                .lineLimit(1)
                .frame(width: viewModel.textWidth, alignment: .leading)
                .animation(.easeInOut(duration: 0.25), value: viewModel.textWidth)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(height: 56)
        .background(Color.clear)
    }

    private var waveform: some View {
        HStack(alignment: .center, spacing: 4) {
            ForEach(Array(viewModel.barHeights.enumerated()), id: \.offset) { index, height in
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.78),
                                Color.white.opacity(0.98)
                            ],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: 5, height: height)
                    .shadow(color: Color.white.opacity(0.14), radius: 6, y: 1)
                    .animation(.easeOut(duration: 0.09), value: viewModel.barHeights[index])
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
