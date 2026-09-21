//
//  IOBChart.swift
//  LoopUI
//
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import LoopKit
import SwiftCharts
import HealthKit
import UIKit


public class IOBChart: ChartProviding {

    static let chartUnit = HKUnit.internationalUnit()

    public init() {
    }

    /// Controls whether the vertical guide marking the current time is drawn.
    public var showsCurrentTimeGuide = true

    /// The chart points for IOB
    public private(set) var iobPoints: [ChartPoint] = [] {
        didSet {
            if let lastDate = iobPoints.last?.x as? ChartAxisValueDate {
                endDate = lastDate.date
            }
        }
    }

    /// The minimum range to display for insulin values.
    private let iobDisplayRangePoints: [ChartPoint] = [0, 1].map {
        return ChartPoint(
            x: ChartAxisValue(scalar: 0),
            y: ChartAxisValueInt($0)
        )
    }

    public private(set) var endDate: Date?

    private var iobChartCache: ChartPointsTouchHighlightLayerViewCache?
}

public extension IOBChart {
    func didReceiveMemoryWarning() {
        iobPoints = []
        iobChartCache = nil
    }

    func generate(withFrame frame: CGRect, xAxisModel: ChartAxisModel, xAxisValues: [ChartAxisValue], axisLabelSettings: ChartLabelSettings, guideLinesLayerSettings: ChartGuideLinesLayerSettings, colors: ChartColorPalette, chartSettings: ChartSettings, labelsWidthY: CGFloat, gestureRecognizer: UIGestureRecognizer?, traitCollection: UITraitCollection) -> Chart
    {
        let minScalar = xAxisValues.first?.scalar ?? 0
        let maxScalar = xAxisValues.last?.scalar ?? 0
        let clippedIOBPoints = iobPoints.clippedToHorizontalRange(
            min: minScalar,
            max: maxScalar,
            unitString: Self.chartUnit.shortLocalizedUnitString(),
            formatter: NumberFormatter.dose
        )

        let hasNegativeIOB = clippedIOBPoints.contains { $0.y.scalar < -0.01 }
        let maxSegmentCount: Double = hasNegativeIOB ? 4 : 3

        let yAxisValues = ChartAxisValuesStaticGenerator.generateYAxisValuesUsingLinearSegmentStep(
            chartPoints: clippedIOBPoints + iobDisplayRangePoints,
            minSegmentCount: 2,
            maxSegmentCount: maxSegmentCount,
            multiple: 0.5,
            axisValueGenerator: { ChartAxisValueDouble($0, labelSettings: axisLabelSettings) },
            addPaddingSegmentIfEdge: false
        )

        let yAxisModel = ChartAxisModel(axisValues: yAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(labelsWidthY))

        let coordsSpace = ChartCoordsSpaceLeftBottomSingleAxis(chartSettings: chartSettings, chartFrame: frame, xModel: xAxisModel, yModel: yAxisModel)

        let (xAxisLayer, yAxisLayer, innerFrame) = (coordsSpace.xAxisLayer, coordsSpace.yAxisLayer, coordsSpace.chartInnerFrame)

        // The IOB area
        let lineModel = ChartLineModel(chartPoints: clippedIOBPoints, lineColor: colors.insulinTint, lineWidth: 2.2, animDuration: 0, animDelay: 0)
        let iobLine = ChartPointsLineLayer(xAxis: xAxisLayer.axis, yAxis: yAxisLayer.axis, lineModels: [lineModel])

        let iobArea = ChartPointsFillsLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            fills: [
                ChartPointsFill(
                    chartPoints: clippedIOBPoints,
                    fillColor: colors.insulinTint.withAlphaComponent(0.20),
                    linearGradient: (
                        topColor: colors.insulinTint.withAlphaComponent(0.55),
                        bottomColor: colors.insulinTint.withAlphaComponent(0.02)
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
            chartPoints: clippedIOBPoints,
            color: colors.insulinTint,
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
            iobChartCache = ChartPointsTouchHighlightLayerViewCache(
                xAxisLayer: xAxisLayer,
                yAxisLayer: yAxisLayer,
                axisLabelSettings: axisLabelSettings,
                chartPoints: clippedIOBPoints,
                tintColor: colors.insulinTint,
                gestureRecognizer: gestureRecognizer
            )
        }

        let layers: [ChartLayer?] = [
            gridLayer,
            currentTimeLayer,
            xAxisLayer,
            yAxisLayer,
            zeroGuidelineLayer,
            iobChartCache?.highlightLayer,
            iobArea,
            iobLine,
            currentLayers.first,
            currentLayers.last
        ]

        return Chart(frame: frame, innerFrame: innerFrame, settings: chartSettings, layers: layers.compactMap { $0 })
    }
}

public extension IOBChart {
    func setIOBValues(_ iobValues: [InsulinValue]) {
        let dateFormatter = DateFormatter(timeStyle: .short)
        let doseFormatter = NumberFormatter.dose

        iobPoints = iobValues.map {
            return ChartPoint(
                x: ChartAxisValueDate(date: $0.startDate, formatter: dateFormatter),
                y: ChartAxisValueDoubleUnit($0.value, unitString: Self.chartUnit.shortLocalizedUnitString(), formatter: doseFormatter)
            )
        }
    }
}
