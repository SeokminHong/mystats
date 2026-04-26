import SwiftUI

struct HistoryChartView: View {
    let series: [MetricChartSeries]
    let timeDomain: ClosedRange<Date>

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            chart
                .frame(height: 96)
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))

            if !series.isEmpty {
                legend
            }
        }
    }

    private var chart: some View {
        Canvas { context, size in
            let axisWidth: CGFloat = 24
            let plotWidth = max(size.width - axisWidth, 1)
            let plotSize = CGSize(width: plotWidth, height: size.height)
            let allValues = series.flatMap(\.values).filter { $0.isFinite }
            guard
                !allValues.isEmpty,
                allValues.count > 1,
                timeDomain.lowerBound < timeDomain.upperBound
            else {
                drawEmptyState(context: context, size: size)
                return
            }

            let independentTrendScale = usesIndependentTrendScale
            let axis = independentTrendScale ? trendAxisLabelDomain : axisDomain(for: allValues)
            drawChartBackground(context: context, size: plotSize)
            drawGrid(context: context, size: plotSize)
            drawAxisLabels(context: context, size: size, axis: axis)
            let plotRects = seriesPlotRects(
                count: independentTrendScale ? series.count : 1,
                in: CGRect(origin: .zero, size: plotSize)
            )

            for (seriesIndex, line) in series.enumerated() where line.values.count > 1 {
                let lineAxis = independentTrendScale ? trendAxisDomain(for: line.values) : axis
                let range = max(lineAxis.max - lineAxis.min, 0.0001)
                let plotRect = independentTrendScale ? plotRects[seriesIndex] : plotRects[0]
                drawSeries(
                    line,
                    seriesIndex: seriesIndex,
                    context: context,
                    plotRect: plotRect,
                    timeRange: timeDomain,
                    axis: lineAxis,
                    valueRange: range
                )
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 9) {
            ForEach(series) { line in
                HStack(spacing: 4) {
                    Circle()
                        .fill(line.tint)
                        .frame(width: 6, height: 6)
                    Text(line.label)
                    Text(line.formattedCurrent)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.caption2)
            }
        }
    }

    private func drawChartBackground(context: GraphicsContext, size: CGSize) {
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .color(.primary.opacity(0.025))
        )
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridColor = Color.secondary.opacity(0.12)
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

    private func drawSeries(
        _ line: MetricChartSeries,
        seriesIndex: Int,
        context: GraphicsContext,
        plotRect: CGRect,
        timeRange: ClosedRange<Date>,
        axis: ChartAxis,
        valueRange: Double
    ) {
        let gapThreshold = gapThreshold(for: line.points)
        var solidPath = Path()
        var hasSolidSegment = false
        var previous: RenderedChartPoint?

        for point in line.points.sorted(by: { $0.timestamp < $1.timestamp }) {
            guard let value = point.value, value.isFinite else {
                previous = nil
                continue
            }

            let current = renderedPoint(
                timestamp: point.timestamp,
                value: value,
                plotRect: plotRect,
                timeRange: timeRange,
                axis: axis,
                valueRange: valueRange
            )

            guard let previousPoint = previous else {
                solidPath.move(to: current.point)
                previous = current
                continue
            }

            if current.timestamp.timeIntervalSince(previousPoint.timestamp) > gapThreshold {
                strokeSolidPath(solidPath, context: context, tint: line.tint, seriesIndex: seriesIndex, hasSegment: hasSolidSegment)
                drawGap(from: previousPoint.point, to: current.point, context: context, tint: line.tint)
                solidPath = Path()
                solidPath.move(to: current.point)
                hasSolidSegment = false
            } else {
                solidPath.addLine(to: current.point)
                hasSolidSegment = true
            }

            previous = current
        }

        strokeSolidPath(solidPath, context: context, tint: line.tint, seriesIndex: seriesIndex, hasSegment: hasSolidSegment)
    }

    private func renderedPoint(
        timestamp: Date,
        value: Double,
        plotRect: CGRect,
        timeRange: ClosedRange<Date>,
        axis: ChartAxis,
        valueRange: Double
    ) -> RenderedChartPoint {
        let duration = max(timeRange.upperBound.timeIntervalSince(timeRange.lowerBound), 0.0001)
        let timeOffset = timestamp.timeIntervalSince(timeRange.lowerBound)
        let x = plotRect.minX + CGFloat(timeOffset / duration) * plotRect.width
        let clamped = min(max(value, axis.min), axis.max)
        let normalized = (clamped - axis.min) / valueRange
        let y = plotRect.maxY - CGFloat(normalized) * plotRect.height

        return RenderedChartPoint(timestamp: timestamp, point: CGPoint(x: x, y: y))
    }

    private func strokeSolidPath(
        _ path: Path,
        context: GraphicsContext,
        tint: Color,
        seriesIndex: Int,
        hasSegment: Bool
    ) {
        guard hasSegment else {
            return
        }

        context.stroke(
            path,
            with: .color(tint),
            style: StrokeStyle(
                lineWidth: seriesIndex == 0 ? 1.7 : 1.45,
                lineCap: .round,
                lineJoin: .round,
                dash: seriesIndex == 0 ? [] : [4, 3]
            )
        )
    }

    private func drawGap(from start: CGPoint, to end: CGPoint, context: GraphicsContext, tint: Color) {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        context.stroke(
            path,
            with: .color(tint.opacity(0.45)),
            style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round, dash: [3, 3])
        )
    }

    private func gapThreshold(for points: [MetricChartPoint]) -> TimeInterval {
        let timestamps = points
            .filter { $0.value?.isFinite == true }
            .map(\.timestamp)
            .sorted()
        let deltas = zip(timestamps.dropFirst(), timestamps)
            .map { next, current in next.timeIntervalSince(current) }
            .filter { $0 > 0 }
            .sorted()
        guard !deltas.isEmpty else {
            return 5
        }

        let medianDelta = deltas[deltas.count / 2]
        return max(medianDelta * 2.5, 5)
    }

    private func drawAxisLabels(context: GraphicsContext, size: CGSize, axis: ChartAxis) {
        let x = size.width - 11
        context.draw(
            Text(axis.upperLabel)
                .font(.caption2)
                .foregroundColor(.secondary),
            at: CGPoint(x: x, y: 5),
            anchor: .center
        )
        context.draw(
            Text(axis.lowerLabel)
                .font(.caption2)
                .foregroundColor(.secondary),
            at: CGPoint(x: x, y: size.height - 6),
            anchor: .center
        )
    }

    private func seriesPlotRects(count: Int, in rect: CGRect) -> [CGRect] {
        guard count > 1 else {
            return [rect]
        }

        let gap: CGFloat = 6
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

    private func axisDomain(for values: [Double]) -> ChartAxis {
        switch commonScale {
        case .some(.fixed(let domain, let lowerLabel, let upperLabel)):
            return ChartAxis(min: domain.lowerBound, max: domain.upperBound, lowerLabel: lowerLabel, upperLabel: upperLabel)
        case .some(.automaticAdaptive):
            return adaptiveAxisDomain(for: values)
        case .some(.automaticFloorZero), .some(.independentTrend), nil:
            return floorZeroAxisDomain(for: values)
        }
    }

    private var usesIndependentTrendScale: Bool {
        !series.isEmpty && series.allSatisfy {
            if case .independentTrend = $0.scale {
                return true
            }
            return false
        }
    }

    private var commonScale: MetricChartScale? {
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
        case .automaticAdaptive:
            return series.allSatisfy {
                if case .automaticAdaptive = $0.scale {
                    return true
                }
                return false
            } ? first : nil
        case .automaticFloorZero:
            return series.allSatisfy {
                if case .automaticFloorZero = $0.scale {
                    return true
                }
                return false
            } ? first : nil
        case .independentTrend:
            return series.allSatisfy {
                if case .independentTrend = $0.scale {
                    return true
                }
                return false
            } ? first : nil
        }
    }

    private var trendAxisLabelDomain: ChartAxis {
        ChartAxis(min: 0, max: 1, lowerLabel: "Low", upperLabel: "High")
    }

    private func trendAxisDomain(for values: [Double]) -> ChartAxis {
        let domain = ChartDomainResolver.trendDomain(for: values)
        return ChartAxis(min: domain.lower, max: domain.upper, lowerLabel: "Low", upperLabel: "High")
    }

    private func adaptiveAxisDomain(for values: [Double]) -> ChartAxis {
        let robustDomain = ChartDomainResolver.robustDomain(for: values)
        let minValue = max(robustDomain.lower, 0)
        let maxValue = max(robustDomain.upper, minValue)
        guard maxValue > 0 else {
            return ChartAxis(min: 0, max: 1, lowerLabel: "0", upperLabel: "1")
        }

        let rawSpan = maxValue - minValue
        let minimumSpan = max(maxValue * 0.08, 1)
        let span = max(rawSpan, minimumSpan)
        let padding = span * 0.12
        var lower = minValue - padding
        var upper = maxValue + padding

        if minValue <= minimumSpan * 0.35 {
            lower = 0
            upper = max(upper, maxValue * 1.08)
        } else {
            lower = max(0, lower)
        }

        if upper <= lower {
            upper = lower + 1
        }

        return ChartAxis(
            min: lower,
            max: upper,
            lowerLabel: abbreviated(lower),
            upperLabel: abbreviated(upper)
        )
    }

    private func floorZeroAxisDomain(for values: [Double]) -> ChartAxis {
        let maxValue = max(values.max() ?? 0, 1)
        return ChartAxis(
            min: 0,
            max: maxValue,
            lowerLabel: "0",
            upperLabel: abbreviated(maxValue)
        )
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

private struct RenderedChartPoint {
    let timestamp: Date
    let point: CGPoint
}
