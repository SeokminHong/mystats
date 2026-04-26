import Foundation

struct MetricValueDomain {
    let lower: Double
    let upper: Double
}

enum ChartDomainResolver {
    static func displayTrendValues(for values: [Double]) -> [Double] {
        guard values.contains(where: { $0 >= 1_024 }) else {
            return values
        }

        return values.map { log1p(max($0, 0)) }
    }

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
        let sorted = values.sorted()
        guard let first = sorted.first, let last = sorted.last else {
            return MetricValueDomain(lower: 0, upper: 1)
        }

        let latestValue = values.last ?? last
        let percentileLower = sorted.count >= 8 ? percentile(0.2, in: sorted) : first
        let percentileUpper = sorted.count >= 8 ? percentile(0.8, in: sorted) : last
        let rawLower = min(percentileLower, latestValue)
        let rawUpper = max(percentileUpper, latestValue)
        let rawSpan = rawUpper - rawLower
        let magnitude = max(abs(rawUpper), abs(rawLower))
        let minimumSpan = max(magnitude * 0.02, 1)
        let span = max(rawSpan, minimumSpan)
        let padding = span * 0.12
        let center = (rawLower + rawUpper) / 2
        let lower = center - span / 2 - padding
        var upper = center + span / 2 + padding

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
