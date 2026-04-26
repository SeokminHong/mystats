struct MetricValueDomain {
    let lower: Double
    let upper: Double
}

enum ChartDomainResolver {
    static func downsample(_ values: [Double], maxCount: Int) -> [Double] {
        guard maxCount > 1, values.count > maxCount else {
            return values
        }

        let step = Double(values.count - 1) / Double(maxCount - 1)
        return (0..<maxCount).map { index in
            values[Int((Double(index) * step).rounded())]
        }
    }

    static func trendDomain(for values: [Double]) -> MetricValueDomain {
        let lowerValue = values.min() ?? 0
        let upperValue = values.max() ?? lowerValue
        let rawSpan = upperValue - lowerValue
        let magnitude = max(abs(upperValue), abs(lowerValue))
        let minimumSpan = max(magnitude * 0.08, 1)
        let span = max(rawSpan, minimumSpan)
        let center = (lowerValue + upperValue) / 2
        let lower = center - span / 2
        var upper = center + span / 2

        if upper <= lower {
            upper = lower + 1
        }

        return MetricValueDomain(lower: lower, upper: upper)
    }

    static func robustDomain(for values: [Double]) -> MetricValueDomain {
        let sorted = values.sorted()
        guard let first = sorted.first, let last = sorted.last else {
            return MetricValueDomain(lower: 0, upper: 1)
        }
        guard sorted.count >= 8 else {
            return MetricValueDomain(lower: first, upper: last)
        }

        return MetricValueDomain(
            lower: percentile(0.1, in: sorted),
            upper: percentile(0.9, in: sorted)
        )
    }

    private static func percentile(_ percentile: Double, in sortedValues: [Double]) -> Double {
        let index = percentile * Double(sortedValues.count - 1)
        let lowerIndex = Int(index.rounded(.down))
        let upperIndex = Int(index.rounded(.up))
        guard lowerIndex != upperIndex else {
            return sortedValues[lowerIndex]
        }

        let fraction = index - Double(lowerIndex)
        return sortedValues[lowerIndex] + (sortedValues[upperIndex] - sortedValues[lowerIndex]) * fraction
    }
}
