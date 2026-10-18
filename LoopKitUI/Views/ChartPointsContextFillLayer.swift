//
//  ChartPointsContextFillLayer.swift
//  Loop
//
//  Copyright © 2017 LoopKit Authors. All rights reserved.
//

import SwiftCharts
import CoreGraphics
import UIKit

struct ChartPointsFill {
    let chartPoints: [ChartPoint]
    let fillColor: UIColor
    let linearGradient: (topColor: UIColor, bottomColor: UIColor)?
    let createContainerPoints: Bool
    let blendMode: CGBlendMode
    fileprivate var screenPoints: [CGPoint] = []

    init?(
        chartPoints: [ChartPoint],
        fillColor: UIColor,
        linearGradient: (topColor: UIColor, bottomColor: UIColor)? = nil,
        createContainerPoints: Bool = true,
        blendMode: CGBlendMode = .normal
    ) {
        guard chartPoints.count > 1 else {
            return nil;
        }

        var chartPoints = chartPoints

        if createContainerPoints {
            // Create a container line at value position 0
            if let first = chartPoints.first {
                chartPoints.insert(ChartPoint(x: first.x, y: ChartAxisValueInt(0)), at: 0)
            }

            if let last = chartPoints.last {
                chartPoints.append(ChartPoint(x: last.x, y: ChartAxisValueInt(0)))
            }
        }

        self.chartPoints = chartPoints
        self.fillColor = fillColor
        self.linearGradient = linearGradient
        self.createContainerPoints = createContainerPoints
        self.blendMode = blendMode
    }

    var areaPath: UIBezierPath {
        let path = UIBezierPath()

        if let point = screenPoints.first {
            path.move(to: point)
        }

        for point in screenPoints.dropFirst() {
            path.addLine(to: point)
        }

        path.close()

        return path
    }
}


extension ChartCoordsSpaceLayer {
    /// Axis endpoints mapped into the same local coordinates as chart.addSubview.
    var plotFrameInContentCoordinates: CGRect {
        let first = modelLocToScreenLoc(x: xAxis.first, y: yAxis.first)
        let last = modelLocToScreenLoc(x: xAxis.last, y: yAxis.last)
        return CGRect(x: min(first.x, last.x), y: min(first.y, last.y),
                      width: abs(last.x - first.x), height: abs(last.y - first.y))
    }
}

final class ChartPointsFillsLayer: ChartCoordsSpaceLayer {
    let fills: [ChartPointsFill]
    private let clipToPlotArea: Bool

    init?(xAxis: ChartAxis, yAxis: ChartAxis, fills: [ChartPointsFill?], clipToPlotArea: Bool = false) {
        self.fills = fills.compactMap({ $0 })
        self.clipToPlotArea = clipToPlotArea

        guard fills.count > 0 else {
            return nil
        }

        super.init(xAxis: xAxis, yAxis: yAxis)
    }

    override func chartInitialized(chart: Chart) {
        super.chartInitialized(chart: chart)

        let viewFrame = clipToPlotArea ? plotFrameInContentCoordinates : chart.bounds
        let view = ChartPointsFillsView(
            frame: viewFrame,
            chartPointsFills: fills.map { (fill) -> ChartPointsFill in
                var fill = fill

                fill.screenPoints = fill.chartPoints.map { (point) -> CGPoint in
                    let location = modelLocToScreenLoc(x: point.x.scalar, y: point.y.scalar)
                    return clipToPlotArea
                        ? CGPoint(x: location.x - viewFrame.minX, y: location.y - viewFrame.minY)
                        : location
                }

                return fill
            }
        )

        view.clipsToBounds = clipToPlotArea
        chart.addSubview(view)
    }
}


class ChartPointsFillsView: UIView {
    let chartPointsFills: [ChartPointsFill]
    var allowsAntialiasing = true

    init(frame: CGRect, chartPointsFills: [ChartPointsFill]) {
        self.chartPointsFills = chartPointsFills

        super.init(frame: frame)

        backgroundColor = .clear
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }

        context.saveGState()
        context.setAllowsAntialiasing(allowsAntialiasing)
        context.setShouldAntialias(allowsAntialiasing)

        for fill in chartPointsFills {
            let path = fill.areaPath
            guard !path.isEmpty else { continue }

            if let gradientColors = fill.linearGradient {
                context.saveGState()
                context.setBlendMode(fill.blendMode)
                context.addPath(path.cgPath)
                context.clip()

                let bounds = path.bounds
                if bounds.height > 0 {
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let cgColors = [gradientColors.topColor.cgColor, gradientColors.bottomColor.cgColor] as CFArray
                    if let gradient = CGGradient(colorsSpace: colorSpace, colors: cgColors, locations: [0.0, 1.0]) {
                        let startPoint = CGPoint(x: bounds.midX, y: bounds.minY)
                        let endPoint = CGPoint(x: bounds.midX, y: bounds.maxY)
                        context.drawLinearGradient(
                            gradient,
                            start: startPoint,
                            end: endPoint,
                            options: [.drawsBeforeStartLocation, .drawsAfterEndLocation]
                        )
                    }
                }
                context.restoreGState()
            } else {
                context.setFillColor(fill.fillColor.cgColor)
                path.fill(with: fill.blendMode, alpha: 1)
            }
        }

        context.restoreGState()
    }
}
