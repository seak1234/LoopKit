//
//  ChartPoint.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit
import SwiftCharts
import UIKit

struct TargetChartBar {
    let points: [ChartPoint]
    let isOverride: Bool
}

extension ChartPoint {
    static func barsForGlucoseRangeSchedule(_ glucoseRangeSchedule: GlucoseRangeSchedule, unit: HKUnit, xAxisValues: [ChartAxisValue], considering potentialOverride: TemporaryScheduleOverride? = nil) -> [TargetChartBar] {
        let targetRanges = glucoseRangeSchedule.quantityBetween(
            start: ChartAxisValueDate.dateFromScalar(xAxisValues.first!.scalar),
            end: ChartAxisValueDate.dateFromScalar(xAxisValues.last!.scalar)
        )

        let dateFormatter = DateFormatter()

        var result = [TargetChartBar?]()

        for (index, range) in targetRanges.enumerated() {
            var startDate = ChartAxisValueDate(date: range.startDate, formatter: dateFormatter)
            var endDate: ChartAxisValueDate

            if index == targetRanges.startIndex, let firstDate = xAxisValues.first as? ChartAxisValueDate {
                startDate = firstDate
            }

            if index == targetRanges.endIndex - 1, let lastDate = xAxisValues.last as? ChartAxisValueDate {
                endDate = lastDate
            } else {
                endDate = ChartAxisValueDate(date: targetRanges[index + 1].startDate, formatter: dateFormatter)
            }

            if let override = potentialOverride,
               startDate.date < endDate.date,
               (override.startDate...override.scheduledEndDate).overlaps(startDate.date...endDate.date)
            {
                result.append(createBar(value: range.value, unit: unit, startDate: startDate, endDate: ChartAxisValueDate(date: override.startDate, formatter: dateFormatter), isOverride: false))
                let targetDuringOverride = override.settings.targetRange ?? range.value
                result.append(createBar(
                    value: targetDuringOverride,
                    unit: unit,
                    startDate: ChartAxisValueDate(date: max(override.startDate, startDate.date), formatter: dateFormatter),
                    endDate: ChartAxisValueDate(date: min(override.scheduledEndDate, endDate.date), formatter: dateFormatter),
                    isOverride: true))
                result.append(createBar(value: range.value, unit: unit, startDate: ChartAxisValueDate(date: override.scheduledEndDate, formatter: dateFormatter), endDate: endDate, isOverride: false))
            } else {
                result.append(createBar(value: range.value, unit: unit, startDate: startDate, endDate: endDate, isOverride: false))
            }
        }

        return result.compactMap { $0 }
    }
    
    static fileprivate func createBar(value: ClosedRange<HKQuantity>, unit: HKUnit, startDate: ChartAxisValueDate, endDate: ChartAxisValueDate, isOverride: Bool) -> TargetChartBar? {
        guard startDate.date < endDate.date else { return nil }
        
        let value = value.doubleRangeWithMinimumIncrement(in: unit)
        let minValue = ChartAxisValueDouble(value.minValue)
        let maxValue = ChartAxisValueDouble(value.maxValue)

        return TargetChartBar(
            points: [
                ChartPoint(x: startDate, y: maxValue),
                ChartPoint(x: endDate, y: maxValue),
                ChartPoint(x: endDate, y: minValue),
                ChartPoint(x: startDate, y: minValue)
            ],
            isOverride: isOverride)
    }

    static func pointsForGlucoseRangeScheduleOverride(_ override: TemporaryScheduleOverride, unit: HKUnit, xAxisValues: [ChartAxisValue], extendEndDateToChart: Bool = false) -> [ChartPoint] {
        guard let targetRange = override.settings.targetRange else {
            return []
        }

        return pointsForGlucoseRangeScheduleOverride(
            range: targetRange.doubleRangeWithMinimumIncrement(in: unit),
            activeInterval: override.activeInterval,
            unit: unit,
            xAxisValues: xAxisValues,
            extendEndDateToChart: extendEndDateToChart
        )
    }

    private static func pointsForGlucoseRangeScheduleOverride(range: DoubleRange, activeInterval: DateInterval, unit: HKUnit, xAxisValues: [ChartAxisValue], extendEndDateToChart: Bool) -> [ChartPoint] {
        guard let lastXAxisValue = xAxisValues.last as? ChartAxisValueDate else {
            return []
        }

        let dateFormatter = DateFormatter()
        let startDateAxisValue = ChartAxisValueDate(date: activeInterval.start, formatter: dateFormatter)
        let displayEndDate = min(lastXAxisValue.date, extendEndDateToChart ? .distantFuture : activeInterval.end)
        let endDateAxisValue = ChartAxisValueDate(date: displayEndDate, formatter: dateFormatter)
        let minValue = ChartAxisValueDouble(range.minValue)
        let maxValue = ChartAxisValueDouble(range.maxValue)

        return [
            ChartPoint(x: startDateAxisValue, y: maxValue),
            ChartPoint(x: endDateAxisValue, y: maxValue),
            ChartPoint(x: endDateAxisValue, y: minValue),
            ChartPoint(x: startDateAxisValue, y: minValue)
        ]
    }
}



extension ChartPoint: TimelineValue {
    public var startDate: Date {
        if let dateValue = x as? ChartAxisValueDate {
            return dateValue.date
        } else {
            return Date.distantPast
        }
    }
}


extension Collection where Element == ChartPoint {
    /// Returns a point at `date` using the chart values surrounding that date.
    ///
    /// The returned point is placed at the exact requested time so it aligns with
    /// the shared current-time guide. Continuous charts interpolate between values;
    /// step charts can retain the latest value by disabling interpolation.
    func pointAtCurrentTime(_ date: Date, interpolating: Bool = true) -> ChartPoint? {
        guard
            let priorValue = reversed().first(where: { $0.startDate <= date }),
            let nextValue = first(where: { $0.startDate >= date })
        else {
            return nil
        }

        let yValue: ChartAxisValue
        let interval = nextValue.startDate.timeIntervalSince(priorValue.startDate)
        if interpolating, interval > 0 {
            let progress = date.timeIntervalSince(priorValue.startDate) / interval
            let scalar = priorValue.y.scalar + progress * (nextValue.y.scalar - priorValue.y.scalar)
            yValue = ChartAxisValue(scalar: scalar)
        } else {
            yValue = priorValue.y
        }

        return ChartPoint(
            x: ChartAxisValueDate(date: date, formatter: DateFormatter(timeStyle: .short)),
            y: yValue
        )
    }
}


func currentTimeGuideLayer(
    xAxis: ChartAxis,
    yAxis: ChartAxis,
    xAxisValues: [ChartAxisValue],
    yAxisValues: [ChartAxisValue],
    color: UIColor,
    date: Date
) -> ChartLayer? {
    guard
        let firstXValue = xAxisValues.first,
        let lastXValue = xAxisValues.last,
        let firstYValue = yAxisValues.first,
        let lastYValue = yAxisValues.last
    else {
        return nil
    }

    let xValue = ChartAxisValueDate(date: date, formatter: DateFormatter(timeStyle: .short))
    guard firstXValue.scalar <= xValue.scalar, xValue.scalar <= lastXValue.scalar else {
        return nil
    }

    let lineModel = ChartLineModel.predictionLine(
        points: [
            ChartPoint(x: xValue, y: firstYValue),
            ChartPoint(x: xValue, y: lastYValue)
        ],
        color: color,
        width: 1
    )
    return ChartPointsLineLayer(
        xAxis: xAxis,
        yAxis: yAxis,
        lineModels: [lineModel]
    )
}


func currentValueLayers(
    xAxis: ChartAxis,
    yAxis: ChartAxis,
    chartPoints: [ChartPoint],
    color: UIColor,
    date: Date,
    interpolating: Bool = true
) -> [ChartLayer] {
    guard let currentPoint = chartPoints.pointAtCurrentTime(date, interpolating: interpolating) else {
        return []
    }

    let glow = ChartPointsScatterCirclesLayer(
        xAxis: xAxis,
        yAxis: yAxis,
        chartPoints: [currentPoint],
        displayDelay: 0,
        itemSize: CGSize(width: 16, height: 16),
        itemFillColor: color.withAlphaComponent(0.25),
        optimized: false
    )
    let dot = ChartPointsScatterCirclesLayer(
        xAxis: xAxis,
        yAxis: yAxis,
        chartPoints: [currentPoint],
        displayDelay: 0,
        itemSize: CGSize(width: 9, height: 9),
        itemFillColor: color,
        optimized: false
    )

    return [glow, dot]
}


private extension ClosedRange where Bound == HKQuantity {
    func doubleRangeWithMinimumIncrement(in unit: HKUnit) -> DoubleRange {
        let increment = unit.chartableIncrement

        var minValue = self.lowerBound.doubleValue(for: unit)
        var maxValue = self.upperBound.doubleValue(for: unit)

        if (maxValue - minValue) < .ulpOfOne {
            minValue -= increment
            maxValue += increment
        }

        return DoubleRange(minValue: minValue, maxValue: maxValue)
    }
}
