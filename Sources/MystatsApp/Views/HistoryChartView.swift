import SwiftUI

struct HistoryChartView: View {
    let series: [MetricChartSeries]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            chart
                .frame(height: 104)
                .padding(10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

            if !series.isEmpty {
                legend
            }
        }
    }

    private var chart: some View {
        Canvas { context, size in
            let allValues = series.flatMap(\.values).filter { $0.isFinite }
            guard let minValue = allValues.min(), let maxValue = allValues.max(), allValues.count > 1 else {
                drawEmptyState(context: context, size: size)
                return
            }

            drawGrid(context: context, size: size)

            let range = maxValue - minValue
            for line in series where line.values.count > 1 {
                let xStep = size.width / CGFloat(line.values.count - 1)
                var path = Path()

                for (index, value) in line.values.enumerated() {
                    let normalized = range == 0 ? 0.5 : (value - minValue) / range
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

                context.stroke(path, with: .color(line.tint), lineWidth: 2)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 12) {
            ForEach(series) { line in
                HStack(spacing: 5) {
                    Circle()
                        .fill(line.tint)
                        .frame(width: 7, height: 7)
                    Text(line.label)
                    Text(line.formattedCurrent)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.caption)
            }
        }
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridColor = Color.secondary.opacity(0.18)
        for index in 1...3 {
            let y = size.height * CGFloat(index) / 4
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: 1)
        }
    }

    private func drawEmptyState(context: GraphicsContext, size: CGSize) {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: size.height / 2))
        path.addLine(to: CGPoint(x: size.width, y: size.height / 2))
        context.stroke(path, with: .color(.secondary.opacity(0.3)), lineWidth: 1)
    }
}
