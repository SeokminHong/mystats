import SwiftUI

struct SparklineChartView: View {
    let series: [MetricMenuChartSeries]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let sanitizedSeries = series
                .map { $0.values.filter(\.isFinite) }
                .filter { $0.count > 1 }

            drawGrid(context: &context, size: size)

            guard !sanitizedSeries.isEmpty else {
                return
            }

            let allValues = sanitizedSeries.flatMap { $0 }
            let minValue = allValues.min() ?? 0
            let maxValue = allValues.max() ?? 1
            let range = max(maxValue - minValue, 0.0001)
            let plotRect = CGRect(
                x: 0.5,
                y: 1,
                width: max(size.width - 1, 1),
                height: max(size.height - 2, 1)
            )

            for (seriesIndex, values) in sanitizedSeries.enumerated() {
                let xStep = plotRect.width / CGFloat(values.count - 1)
                var path = Path()

                for (index, value) in values.enumerated() {
                    let normalized = (value - minValue) / range
                    let point = CGPoint(
                        x: plotRect.minX + CGFloat(index) * xStep,
                        y: plotRect.maxY - CGFloat(normalized) * plotRect.height
                    )

                    if index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }

                context.stroke(
                    path,
                    with: .color(seriesColor(at: seriesIndex)),
                    style: StrokeStyle(
                        lineWidth: seriesIndex == 0 ? 1 : 0.9,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: seriesIndex == 0 ? [] : [2, 2]
                    )
                )
            }
        }
        .frame(height: 12)
        .accessibilityHidden(true)
    }

    private func drawGrid(context: inout GraphicsContext, size: CGSize) {
        let gridColor = tint.opacity(0.18)
        let rows = [size.height - 0.5, size.height * 0.5]

        for y in rows {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 0.5)
        }
    }

    private func seriesColor(at index: Int) -> Color {
        index == 0 ? tint : tint.opacity(0.58)
    }
}
