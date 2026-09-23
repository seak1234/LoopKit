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


public extension Collection where Element == ChartPoint {
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

    /// Clips a collection of ChartPoints ordered chronologically by x.scalar to a horizontal scalar range [minScalar, maxScalar].
    /// Segments intersecting minScalar or maxScalar are linearly interpolated.
    func clippedToHorizontalRange(
        min minScalar: Double,
        max maxScalar: Double,
        unitString: String? = nil,
        formatter: NumberFormatter? = nil
    ) -> [ChartPoint] {
        guard !isEmpty, minScalar < maxScalar else { return [] }

        let defaultDateFormatter = DateFormatter(timeStyle: .short)
        func makeInterpolatedPoint(targetScalar: Double, p1: ChartPoint, p2: ChartPoint) -> ChartPoint {
            let dx = p2.x.scalar - p1.x.scalar
            let ratio = dx != 0 ? (targetScalar - p1.x.scalar) / dx : 0
            let interpolatedY = p1.y.scalar + ratio * (p2.y.scalar - p1.y.scalar)

            let xVal = ChartAxisValueDate(date: Date(timeIntervalSince1970: targetScalar), formatter: defaultDateFormatter)

            let yVal: ChartAxisValue
            let resolvedUnit = unitString ?? (p1.y as? ChartAxisValueDoubleUnit)?.unitString ?? (p2.y as? ChartAxisValueDoubleUnit)?.unitString
            let resolvedFormatter = formatter ?? (p1.y as? ChartAxisValueDoubleUnit)?.formatter ?? (p2.y as? ChartAxisValueDoubleUnit)?.formatter

            if let unit = resolvedUnit, let fmt = resolvedFormatter {
                yVal = ChartAxisValueDoubleUnit(interpolatedY, unitString: unit, formatter: fmt)
            } else if let fmt = resolvedFormatter {
                yVal = ChartAxisValueDouble(interpolatedY, formatter: fmt)
            } else {
                yVal = ChartAxisValueDouble(interpolatedY)
            }

            return ChartPoint(x: xVal, y: yVal)
        }

        var result: [ChartPoint] = []
        var prev: ChartPoint? = nil

        for point in self {
            let scalar = point.x.scalar

            if scalar < minScalar {
                prev = point
                continue
            }

            if scalar >= minScalar && scalar <= maxScalar {
                if let p = prev, p.x.scalar < minScalar, scalar > minScalar {
                    result.append(makeInterpolatedPoint(targetScalar: minScalar, p1: p, p2: point))
                }
                result.append(point)
                prev = point
            } else { // scalar > maxScalar
                if let p = prev {
                    if p.x.scalar < minScalar {
                        result.append(makeInterpolatedPoint(targetScalar: minScalar, p1: p, p2: point))
                        result.append(makeInterpolatedPoint(targetScalar: maxScalar, p1: p, p2: point))
                    } else if p.x.scalar < maxScalar {
                        result.append(makeInterpolatedPoint(targetScalar: maxScalar, p1: p, p2: point))
                    }
                }
                prev = point
                break
            }
        }

        return result
    }
}


public final class ChartCurrentTimeGuideLayer: ChartPointsLineLayer<ChartPoint> {
    public private(set) var guideAlpha: CGFloat = 1.0

    public func setAlpha(_ alpha: CGFloat) {
        self.guideAlpha = alpha
        lineViews.forEach { $0.alpha = alpha }
    }

    override public func display(chart: Chart) {
        super.display(chart: chart)
        lineViews.forEach { $0.alpha = guideAlpha }
    }
}


func currentTimeGuideLayer(
    xAxis: ChartAxis,
    yAxis: ChartAxis,
    xAxisValues: [ChartAxisValue],
    yAxisValues: [ChartAxisValue],
    color: UIColor,
    date: Date
) -> ChartCurrentTimeGuideLayer? {
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
    return ChartCurrentTimeGuideLayer(
        xAxis: xAxis,
        yAxis: yAxis,
        lineModels: [lineModel]
    )
}


public final class ChartCurrentValueCircleLayer: ChartCoordsSpaceLayer {
    public let chartPoint: ChartPoint
    public let itemSize: CGSize
    public let fillColor: UIColor
    public let zPosition: CGFloat

    public private(set) var circleView: UIView?
    public private(set) var circleAlpha: CGFloat = 1.0

    public func setAlpha(_ alpha: CGFloat) {
        self.circleAlpha = alpha
        circleView?.alpha = alpha
    }

    public init(
        xAxis: ChartAxis,
        yAxis: ChartAxis,
        chartPoint: ChartPoint,
        itemSize: CGSize,
        fillColor: UIColor,
        zPosition: CGFloat = 1000
    ) {
        self.chartPoint = chartPoint
        self.itemSize = itemSize
        self.fillColor = fillColor
        self.zPosition = zPosition
        super.init(xAxis: xAxis, yAxis: yAxis)
    }

    override public func chartInitialized(chart: Chart) {
        super.chartInitialized(chart: chart)

        let view = UIView(frame: CGRect(origin: .zero, size: itemSize))
        view.backgroundColor = fillColor
        view.layer.cornerRadius = min(itemSize.width, itemSize.height) / 2
        view.layer.masksToBounds = true
        view.layer.zPosition = zPosition
        view.isUserInteractionEnabled = false
        view.alpha = circleAlpha
        self.circleView = view

        chart.view.addSubview(view)
        updatePosition()
    }

    override public func update() {
        super.update()
        updatePosition()
    }

    override public func handleAxisInnerFrameChange(_ xLow: ChartAxisLayerWithFrameDelta?, yLow: ChartAxisLayerWithFrameDelta?, xHigh: ChartAxisLayerWithFrameDelta?, yHigh: ChartAxisLayerWithFrameDelta?) {
        super.handleAxisInnerFrameChange(xLow, yLow: yLow, xHigh: xHigh, yHigh: yHigh)
        updatePosition()
    }

    override public func zoom(_ x: CGFloat, y: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        super.zoom(x, y: y, centerX: centerX, centerY: centerY)
        updatePosition()
    }

    override public func zoom(_ scaleX: CGFloat, scaleY: CGFloat, centerX: CGFloat, centerY: CGFloat) {
        super.zoom(scaleX, scaleY: scaleY, centerX: centerX, centerY: centerY)
        updatePosition()
    }

    override public func pan(_ deltaX: CGFloat, deltaY: CGFloat) {
        super.pan(deltaX, deltaY: deltaY)
        updatePosition()
    }

    override public func chartViewDrawing(context: CGContext, chart: Chart) {
        super.chartViewDrawing(context: context, chart: chart)
        updatePosition()
    }

    private func updatePosition() {
        guard let chart = chart, let circleView = circleView else { return }

        let isVisible = chartPoint.x.scalar >= xAxis.first && chartPoint.x.scalar <= xAxis.last
        circleView.isHidden = !isVisible

        if isVisible {
            let screenLoc = modelLocToGlobalScreenLoc(x: chartPoint.x.scalar, y: chartPoint.y.scalar)
            if circleView.center != screenLoc {
                circleView.center = screenLoc
            }
            chart.view.bringSubviewToFront(circleView)
        }
    }

    deinit {
        circleView?.removeFromSuperview()
    }
}


func currentValueLayers(
    xAxis: ChartAxis,
    yAxis: ChartAxis,
    chartPoints: [ChartPoint],
    color: UIColor,
    date: Date,
    interpolating: Bool = true
) -> [ChartCurrentValueCircleLayer] {
    guard let currentPoint = chartPoints.pointAtCurrentTime(date, interpolating: interpolating) else {
        return []
    }

    let glow = ChartCurrentValueCircleLayer(
        xAxis: xAxis,
        yAxis: yAxis,
        chartPoint: currentPoint,
        itemSize: CGSize(width: 16, height: 16),
        fillColor: color.withAlphaComponent(0.25),
        zPosition: 999
    )
    let dot = ChartCurrentValueCircleLayer(
        xAxis: xAxis,
        yAxis: yAxis,
        chartPoint: currentPoint,
        itemSize: CGSize(width: 9, height: 9),
        fillColor: color,
        zPosition: 1000
    )
    let innerDot = ChartCurrentValueCircleLayer(
        xAxis: xAxis,
        yAxis: yAxis,
        chartPoint: currentPoint,
        itemSize: CGSize(width: 5, height: 5),
        fillColor: .white,
        zPosition: 1001
    )

    return [glow, dot, innerDot]
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
