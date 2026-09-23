//
//  DoseChart.swift
//  LoopUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftCharts
import UIKit

fileprivate struct DosePointsCache {
    let startDate: Date
    let endDate: Date
    let basal: [ChartPoint]
    let basalFill: [ChartPoint]
    let bolus: [ChartPoint]
    let highlight: [ChartPoint]
}

public class DoseChart: ChartProviding {
    public init() {
        doseEntries = []
    }

    /// Controls whether the vertical guide marking the current time is drawn.
    public var showsCurrentTimeGuide = true
    
    public var doseEntries: [DoseEntry] {
        didSet {
            pointsCache = nil
        }
    }

    private var pointsCache: DosePointsCache? {
        didSet {
            if let pointsCache = pointsCache {
                if let lastDate = pointsCache.highlight.last?.x as? ChartAxisValueDate {
                    endDate = lastDate.date
                }
            }
        }
    }

    /// The minimum range to display for insulin values.
    private let doseDisplayRangePoints: [ChartPoint] = [0, 1].map {
        return ChartPoint(
            x: ChartAxisValue(scalar: 0),
            y: ChartAxisValueInt($0)
        )
    }

    public private(set) var endDate: Date?

    private var doseChartCache: ChartPointsTouchHighlightLayerViewCache?
}

public extension DoseChart {
    func didReceiveMemoryWarning() {
        pointsCache = nil
        doseChartCache = nil
    }

    func generate(withFrame frame: CGRect, xAxisModel: ChartAxisModel, xAxisValues: [ChartAxisValue], axisLabelSettings: ChartLabelSettings, guideLinesLayerSettings: ChartGuideLinesLayerSettings, colors: ChartColorPalette, chartSettings: ChartSettings, labelsWidthY: CGFloat, gestureRecognizer: UIGestureRecognizer?, traitCollection: UITraitCollection) -> Chart
    {
        let integerFormatter = NumberFormatter.integer
        
        let startDate = ChartAxisValueDate.dateFromScalar(xAxisValues.first!.scalar)
        let endDate = ChartAxisValueDate.dateFromScalar(xAxisValues.last!.scalar)
        
        let points = generateDosePoints(startDate: startDate, endDate: endDate)

        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesUsingLinearSegmentStep(
            chartPoints: points.basal + points.bolus + doseDisplayRangePoints,
            minSegmentCount: 2,
            maxSegmentCount: 3,
            multiple: log(2) / 2,
            axisValueGenerator: { ChartAxisValueDoubleLog(screenLocDouble: $0, formatter: integerFormatter, labelSettings: axisLabelSettings) },
            addPaddingSegmentIfEdge: true)
        
        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)

        // The dose area
        let lineModel = ChartLineModel(chartPoints: points.basal, lineColor: colors.insulinTint, lineWidth: 1.5, animDuration: 0, animDelay: 0)
        let doseLine = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [lineModel])

        let doseArea = ChartPointsFillsLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            fills: [ChartPointsFill(
                chartPoints: points.basalFill,
                fillColor: colors.insulinTint.withAlphaComponent(0.28),
                linearGradient: (
                    topColor: colors.insulinTint.withAlphaComponent(0.40),
                    bottomColor: colors.insulinTint.withAlphaComponent(0.08)
                ),
                createContainerPoints: false
            )]
        )

        // bolus points
        let bolusPointSize: Double = 12
        let bolusLayer: ChartPointsScatterDownTrianglesLayer<ChartPoint>?

        if points.bolus.count > 0 {
            bolusLayer = ChartPointsScatterDownTrianglesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: points.bolus, displayDelay: 0, itemSize: CGSize(width: bolusPointSize, height: bolusPointSize), itemFillColor: colors.insulinTint)
        } else {
            bolusLayer = nil
        }

        // Grid lines
        let gridLayer = ChartGuideLinesForValuesLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, settings: guideLinesLayerSettings, axisValuesX: Array(xAxisValues.dropFirst().dropLast()), axisValuesY: yAxisValues)

        let currentDate = Date()
        let currentTimeLayer = showsCurrentTimeGuide
            ? currentTimeGuideLayer(
                xAxis: xAxisLayer.axis,
                yAxis: yAxisLayer.axis,
                xAxisValues: xAxisValues,
                yAxisValues: yAxisValues,
                color: colors.axisLabel.withAlphaComponent(0.35),
                date: currentDate
            )
            : nil
        // 0-line
        let dummyZeroChartPoint = ChartPoint(x: ChartAxisValueDouble(0), y: ChartAxisValueDouble(0))
        let zeroGuidelineLayer = ChartPointsViewsLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, chartPoints: [dummyZeroChartPoint], viewGenerator: {(chartPointModel, layer, chart) -> UIView? in
            let width: CGFloat = 1.0
            let viewFrame = CGRect(x: chart.contentView.bounds.minX, y: chartPointModel.screenLoc.y - width / 2, width: chart.contentView.bounds.size.width, height: width)

            let v = UIView(frame: viewFrame)
            v.backgroundColor = UIColor { traitCollection in
                traitCollection.userInterfaceStyle == .dark
                    ? UIColor(white: 1.0, alpha: 0.14)
                    : UIColor(white: 0.0, alpha: 0.12)
            }
            return v
        })

        if gestureRecognizer != nil {
            doseChartCache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: xAxisLayer,
                yAxisLayer: yAxisLayer,
                axisLabelSettings: axisLabelSettings,
                chartPoints: points.highlight,
                tintColor: colors.insulinTint,
                selectionGuideColor: colors.axisLabel.withAlphaComponent(0.35),
                gestureRecognizer: gestureRecognizer,
                onHighlightStateChange: { [weak currentTimeLayer] isHighlighting in
                    let alpha: CGFloat = isHighlighting ? 0 : 1
                    currentTimeLayer?.setAlpha(alpha)
                }
            )
        }

        let layers: [ChartLayer?] = [
            gridLayer,
            currentTimeLayer,
            xAxisLayer,
            yAxisLayer,
            zeroGuidelineLayer,
            doseChartCache?.highlightLayer,
            doseArea,
            doseLine,
            bolusLayer
        ]

        let chart = Chart(frame: frame, innerFrame: innerFrame, settings: chartSettings, layers: layers.compactMap { $0 })

        // the bolus points are drawn in the chart's drawersContentView. Update the drawersContentView frame to allow the bolus points to be drawn without clipping
        var frame = chart.drawersContentView.frame
        frame.size.height = frame.height+CGFloat(bolusPointSize/2)
        chart.drawersContentView.frame = frame.offsetBy(dx: 0, dy: -CGFloat(bolusPointSize/2))

        return chart
    }
    
    private func generateDosePoints(startDate: Date, endDate: Date) -> DosePointsCache {
        if let pointsCache = pointsCache, pointsCache.startDate == startDate, pointsCache.endDate == endDate {
            return pointsCache
        }
        
        let dateFormatter = DateFormatter(timeStyle: .short)
        let doseFormatter = NumberFormatter.dose

        var basalPoints = [ChartPoint]()
        var basalFillPoints = [ChartPoint]()
        var bolusPoints = [ChartPoint]()
        var highlightPoints = [ChartPoint]()
        
        for entry in doseEntries {
            let time = entry.endDate.timeIntervalSince(entry.startDate)

            if entry.type == .bolus && entry.netBasalUnits > 0 {
                if entry.startDate >= startDate && entry.startDate <= endDate {
                    let x = ChartAxisValueDate(date: entry.startDate, formatter: dateFormatter)
                    let y = ChartAxisValueDoubleLog(actualDouble: entry.unitsInDeliverableIncrements, unitString: "U", formatter: doseFormatter)

                    let point = ChartPoint(x: x, y: y)
                    bolusPoints.append(point)
                    highlightPoints.append(point)
                }
            } else if time > 0 {
                guard entry.endDate > startDate && entry.startDate < endDate else {
                    continue
                }

                let clampedStartDate = max(startDate, entry.startDate)
                let clampedEndDate = min(endDate, entry.endDate)
                guard clampedEndDate > clampedStartDate else {
                    continue
                }

                let startX = ChartAxisValueDate(date: clampedStartDate, formatter: dateFormatter)
                let endX = ChartAxisValueDate(date: clampedEndDate, formatter: dateFormatter)
                let zero = ChartAxisValueInt(0)
                let rate = entry.netBasalUnitsPerHour
                let value = ChartAxisValueDoubleLog(actualDouble: rate, unitString: "U/hour", formatter: doseFormatter)

                let valuePoints: [ChartPoint]

                if abs(rate) > .ulpOfOne {
                    valuePoints = [
                        ChartPoint(x: startX, y: value),
                        ChartPoint(x: endX, y: value)
                    ]
                } else {
                    valuePoints = []
                }
                
                basalFillPoints += [ChartPoint(x: startX, y: zero)] + valuePoints + [ChartPoint(x: endX, y: zero)]
                
                if entry.startDate > startDate {
                    basalPoints += [ChartPoint(x: startX, y: zero)]
                }
                basalPoints += valuePoints + [ChartPoint(x: endX, y: zero)]

                highlightPoints += valuePoints
            }
        }
        
        let pointsCache = DosePointsCache(startDate: startDate, endDate: endDate, basal: basalPoints, basalFill: basalFillPoints, bolus: bolusPoints, highlight: highlightPoints)
        self.pointsCache = pointsCache
        return pointsCache
    }
}
