import SwiftUI

struct SparklineChartView: View {
    let values: [Double]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            guard values.count > 1 else {
                return
            }

            let sanitized = values.filter { $0.isFinite }
            guard sanitized.count > 1 else {
                return
            }

            let minValue = sanitized.min() ?? 0
            let maxValue = sanitized.max() ?? 1
            let range = max(maxValue - minValue, 0.0001)
            let xStep = size.width / CGFloat(sanitized.count - 1)

            var path = Path()
            for (index, value) in sanitized.enumerated() {
                let normalized = (value - minValue) / range
                let point = CGPoint(
                    x: CGFloat(index) * xStep,
                    y: size.height - CGFloat(normalized) * size.height
                )

                if index == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }

            context.stroke(path, with: .color(tint), lineWidth: 1)
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }
}
