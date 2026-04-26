import SwiftUI

struct SparklineChartView: View {
    let series: [MetricMenuChartSeries]
    let tint: Color

    var body: some View {
        Canvas { context, size in
            let sanitizedSeries = series
                .map { ChartDomainResolver.downsample($0.values.filter(\.isFinite), maxCount: 32) }
                .map { ChartDomainResolver.displayTrendValues(for: $0) }
                .filter { $0.count > 1 }

            drawGrid(context: &context, size: size)

            guard !sanitizedSeries.isEmpty else {
                return
            }

            let plotRect = CGRect(
                x: 0.5,
                y: 1,
                width: max(size.width - 1, 1),
                height: max(size.height - 2, 1)
            )
            let plotRects = seriesPlotRects(count: sanitizedSeries.count, in: plotRect)

            for (seriesIndex, values) in sanitizedSeries.enumerated() {
                let seriesRect = plotRects[seriesIndex]
                let axis = ChartDomainResolver.trendDomain(for: values)
                let range = max(axis.upper - axis.lower, 0.0001)
                let xStep = seriesRect.width / CGFloat(values.count - 1)
                var path = Path()

                for (index, value) in values.enumerated() {
                    let normalized = min(max((value - axis.lower) / range, 0), 1)
                    let point = CGPoint(
                        x: seriesRect.minX + CGFloat(index) * xStep,
                        y: seriesRect.maxY - CGFloat(normalized) * seriesRect.height
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
                        lineWidth: seriesIndex == 0 ? 1.2 : 1.05,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: seriesIndex == 0 ? [] : [2, 2]
                    )
                )
            }
        }
        .frame(height: 14)
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

    private func seriesPlotRects(count: Int, in rect: CGRect) -> [CGRect] {
        guard count > 1 else {
            return [rect]
        }

        let gap: CGFloat = 1
        let laneHeight = max((rect.height - gap * CGFloat(count - 1)) / CGFloat(count), 1)
        return (0..<count).map { index in
            CGRect(
                x: rect.minX,
                y: rect.minY + CGFloat(index) * (laneHeight + gap),
                width: rect.width,
                height: laneHeight
            )
        }
    }

    private func seriesColor(at index: Int) -> Color {
        index == 0 ? tint : tint.opacity(0.58)
    }
}
