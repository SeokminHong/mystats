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
            let plotWidth = max(size.width - 42, 1)
            let plotSize = CGSize(width: plotWidth, height: size.height)
            let allValues = series.flatMap(\.values).filter { $0.isFinite }
            guard !allValues.isEmpty, allValues.count > 1 else {
                drawEmptyState(context: context, size: size)
                return
            }

            let axis = axisDomain(for: allValues)
            drawGrid(context: context, size: plotSize)
            drawAxisLabels(context: context, size: size, axis: axis)

            let range = max(axis.max - axis.min, 0.0001)
            for line in series where line.values.count > 1 {
                let xStep = plotSize.width / CGFloat(line.values.count - 1)
                var path = Path()

                for (index, value) in line.values.enumerated() {
                    let clamped = min(max(value, axis.min), axis.max)
                    let normalized = (clamped - axis.min) / range
                    let point = CGPoint(
                        x: CGFloat(index) * xStep,
                        y: plotSize.height - CGFloat(normalized) * plotSize.height
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
        for index in 0...4 {
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

    private func drawAxisLabels(context: GraphicsContext, size: CGSize, axis: ChartAxis) {
        let x = size.width - 18
        context.draw(
            Text(axis.upperLabel)
                .font(.caption2)
                .foregroundColor(.secondary),
            at: CGPoint(x: x, y: 6),
            anchor: .center
        )
        context.draw(
            Text(axis.lowerLabel)
                .font(.caption2)
                .foregroundColor(.secondary),
            at: CGPoint(x: x, y: size.height - 7),
            anchor: .center
        )
    }

    private func axisDomain(for values: [Double]) -> ChartAxis {
        if case let .fixed(domain, lowerLabel, upperLabel)? = fixedScale {
            return ChartAxis(min: domain.lowerBound, max: domain.upperBound, lowerLabel: lowerLabel, upperLabel: upperLabel)
        }

        let maxValue = max(values.max() ?? 0, 1)
        return ChartAxis(
            min: 0,
            max: maxValue,
            lowerLabel: "0",
            upperLabel: abbreviated(maxValue)
        )
    }

    private var fixedScale: MetricChartScale? {
        guard let first = series.first?.scale else {
            return nil
        }

        switch first {
        case .fixed:
            return series.allSatisfy {
                if case .fixed = $0.scale {
                    return true
                }
                return false
            } ? first : nil
        case .automaticFloorZero:
            return nil
        }
    }

    private func abbreviated(_ value: Double) -> String {
        if value >= 1_000_000_000 {
            return "\(Int((value / 1_000_000_000).rounded()))G"
        }
        if value >= 1_000_000 {
            return "\(Int((value / 1_000_000).rounded()))M"
        }
        if value >= 1_000 {
            return "\(Int((value / 1_000).rounded()))K"
        }
        return "\(Int(value.rounded()))"
    }
}

private struct ChartAxis {
    let min: Double
    let max: Double
    let lowerLabel: String
    let upperLabel: String
}
