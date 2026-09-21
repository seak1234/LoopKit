//
//  COBChart.swift
//  LoopUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit
import LoopKit
import SwiftCharts
import UIKit


public class COBChart: ChartProviding {
    public init() {
    }

    /// Controls whether the vertical guide marking the current time is drawn.
    public var showsCurrentTimeGuide = true

    /// The chart points for COB
    public private(set) var cobPoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = cobPoints.last?.x as? ChartAxisValueDate {
                endDate = lastDate.date
            }
        }
    }

    /// The minimum range to display for COB values.
    private var cobDisplayRangePoints: [ChartPoint] = [0, 10].map {
        return ChartPoint(
            x: ChartAxisValue(scalar: 0),
            y: ChartAxisValueInt($0)
        )
    }

    public private(set) var endDate: Date?

    private var cobChartCache: ChartPointsTouchHighlightLayerViewCache?
}

public extension COBChart {
    func didReceiveMemoryWarning() {
        cobPoints = []
        cobChartCache = nil
    }

    func generate(withFrame frame: CGRect, xAxisModel: ChartAxisModel, xAxisValues: [ChartAxisValue], axisLabelSettings: ChartLabelSettings, guideLinesLayerSettings: ChartGuideLinesLayerSettings, colors: ChartColorPalette, chartSettings: ChartSettings, labelsWidthY: CGFloat, gestureRecognizer: UIGestureRecognizer?, traitCollection: UITraitCollection) -> Chart
    {
        let minScalar = xAxisValues.first?.scalar ?? 0
        let maxScalar = xAxisValues.last?.scalar ?? 0
        let clippedCOBPoints = cobPoints.clippedToHorizontalRange(
            min: minScalar,
            max: maxScalar,
            unitString: HKUnit.gram().unitString,
            formatter: NumberFormatter.integer
        )

        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesWithChartPoints(clippedCOBPoints + cobDisplayRangePoints, minSegmentCount: 2, maxSegmentCount: 3, multiple: 10, axisValueGenerator: { ChartAxisValueDouble($0, labelSettings: axisLabelSettings) }, addPaddingSegmentIfEdge: false)

        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)

        // The COB area
        let lineModel = ChartLineModel(chartPoints: clippedCOBPoints, lineColor: colors.carbTint, lineWidth: 2.2, animDuration: 0, animDelay: 0)
        let cobLine = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [lineModel])

        let cobArea = ChartPointsFillsLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            fills: [
                ChartPointsFill(
                    chartPoints: clippedCOBPoints,
                    fillColor: colors.carbTint.withAlphaComponent(0.35),
                    linearGradient: (
                        topColor: colors.carbTint.withAlphaComponent(0.50),
                        bottomColor: colors.carbTint.withAlphaComponent(0.02)
                    )
                )
            ]
        )

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
        let currentLayers = currentValueLayers(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            chartPoints: clippedCOBPoints,
            color: colors.carbTint,
            date: currentDate
        )

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
            cobChartCache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: xAxisLayer,
                yAxisLayer: yAxisLayer,
                axisLabelSettings: axisLabelSettings,
                chartPoints: clippedCOBPoints,
                tintColor: colors.carbTint,
                gestureRecognizer: gestureRecognizer
            )
        }

        let layers: [ChartLayer?] = [
            gridLayer,
            currentTimeLayer,
            xAxisLayer,
            yAxisLayer,
            zeroGuidelineLayer,
            cobChartCache?.highlightLayer,
            cobArea,
            cobLine,
            currentLayers.first,
            currentLayers.last
        ]

        return Chart(frame: frame, innerFrame: innerFrame, settings: chartSettings, layers: layers.compactMap { $0 })
    }
}

public extension COBChart {
    func setCOBValues(_ cobValues: [CarbValue]) {
        let dateFormatter = DateFormatter(timeStyle: .short)
        let integerFormatter = NumberFormatter.integer

        let unit = HKUnit.gram()
        let unitString = unit.unitString

        cobPoints = cobValues.map {
            ChartPoint(
                x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                y: ChartAxisValueDoubleUnit($0.quantity.doubleValue(for: unit), unitString: unitString, formatter: integerFormatter)
            )
        }
    }
}
