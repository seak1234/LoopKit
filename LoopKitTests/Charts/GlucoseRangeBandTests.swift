import XCTest
import UIKit
import HealthKit
import LoopKit
import SwiftCharts
@testable import LoopKitUI

class GlucoseRangeBandTests: XCTestCase {
    func testRangeUsesDisplayUnitsAndCanBeRemoved() throws {
        for unit in [HKUnit.milligramsPerDeciliter, .millimolesPerLiter] {
            let glucose = PredictedGlucoseChart()
            glucose.glucoseUnit = unit
            let minimum = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 40)
            let maximum = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)
            let lower = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)
            let upper = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 145)
            glucose.glucoseDisplayRange = minimum...maximum
            glucose.inRangeDisplayRange = lower...upper
            let colors = ChartColorPalette(axisLine: .gray, axisLabel: .gray, grid: .gray,
                                           glucoseTint: .blue, insulinTint: .orange, carbTint: .green)
            let manager = ChartsManager(colors: colors, settings: ChartSettings(), charts: [glucose], traitCollection: UITraitCollection())
            manager.startDate = Date().addingTimeInterval(-3600)
            manager.prerender()
            let frame = CGRect(x: 0, y: 0, width: 320, height: 200)
            let chart = try XCTUnwrap(manager.chart(atIndex: 0, frame: frame))
            let band = try XCTUnwrap(chart.contentView.subviews.compactMap { $0 as? GlucoseRangeBandView }.first)
            let labels = band.subviews.compactMap { ($0 as? UILabel)?.text }
            let formatter = QuantityFormatter(for: unit)
            XCTAssertTrue(labels.contains(try XCTUnwrap(formatter.string(from: lower, includeUnit: false))))
            XCTAssertTrue(labels.contains(try XCTUnwrap(formatter.string(from: upper, includeUnit: false))))
            XCTAssertGreaterThan(band.bandRect.width, 0)
            XCTAssertGreaterThan(band.bandRect.height, 0)

            glucose.inRangeDisplayRange = nil
            manager.invalidateChart(atIndex: 0)
            let unshaded = try XCTUnwrap(manager.chart(atIndex: 0, frame: frame))
            XCTAssertFalse(unshaded.contentView.subviews.contains { $0 is GlucoseRangeBandView })
        }
    }

    func testBothBandsAlignWithAxisEndpointsAcrossChartSizesAndTimeWindows() throws {
        for hours in [1.0, 3, 6, 12, 24] {
            for width in [320.0, 768] {
                let glucose = PredictedGlucoseChart()
                let minimum = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 40)
                let maximum = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 200)
                let lower = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 80)
                let upper = HKQuantity(unit: .milligramsPerDeciliter, doubleValue: 145)
                glucose.glucoseDisplayRange = minimum...maximum
                glucose.inRangeDisplayRange = lower...upper
                glucose.targetGlucoseSchedule = try XCTUnwrap(GlucoseRangeSchedule(
                    unit: .milligramsPerDeciliter,
                    dailyItems: [RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 100, maxValue: 110))]
                ))
                let start = Date(timeIntervalSince1970: 1_700_000_017)
                let formatter = DateFormatter()
                let values = [start, start.addingTimeInterval(hours * 3600)].map {
                    ChartAxisValueDate(date: $0, formatter: formatter)
                }
                values.forEach { $0.hidden = true }
                let axisModel = ChartAxisModel(axisValues: values, lineColor: .gray, labelSpaceReservationMode: .fixed(20))
                var settings = ChartSettings()
                settings.leading = 11
                settings.trailing = 23
                settings.top = 17
                settings.bottom = 9
                settings.labelsToAxisSpacingY = 6
                settings.clipInnerFrame = false
                let colors = ChartColorPalette(axisLine: .gray, axisLabel: .gray, grid: .gray,
                                               glucoseTint: .blue, insulinTint: .orange, carbTint: .green)
                let chart = glucose.generate(
                    withFrame: CGRect(x: 0, y: 0, width: width, height: 220),
                    xAxisModel: axisModel, xAxisValues: values,
                    axisLabelSettings: ChartLabelSettings(font: .systemFont(ofSize: 13)),
                    guideLinesLayerSettings: ChartGuideLinesLayerSettings(linesColor: .gray),
                    colors: colors, chartSettings: settings, labelsWidthY: 30,
                    gestureRecognizer: nil, traitCollection: UITraitCollection()
                )
                let band = try XCTUnwrap(chart.contentView.subviews.compactMap { $0 as? GlucoseRangeBandView }.first)
                let targets = try XCTUnwrap(chart.contentView.subviews.compactMap { $0 as? ChartPointsFillsView }.first)
                let bandFrame = band.convert(band.bounds, to: chart.view)
                let targetFrame = targets.convert(targets.bounds, to: chart.view)
                for frame in [bandFrame, targetFrame] {
                    XCTAssertEqual(frame.minX, chart.innerFrame.minX, accuracy: 0.001)
                    XCTAssertEqual(frame.maxX, chart.innerFrame.maxX, accuracy: 0.001)
                    XCTAssertEqual(frame.minY, chart.innerFrame.minY, accuracy: 0.001)
                    XCTAssertEqual(frame.maxY, chart.innerFrame.maxY, accuracy: 0.001)
                }
                XCTAssertTrue(targets.clipsToBounds)
                let targetPath = try XCTUnwrap(targets.chartPointsFills.first).areaPath.bounds
                XCTAssertEqual(targetPath.minX, 0, accuracy: 0.001)
                XCTAssertEqual(targetPath.maxX, targets.bounds.width, accuracy: 0.001)
            }
        }
    }

    func testBandUsesContentCoordinatesForItsFrameAndBoundaries() throws {
        let plotFrame = CGRect(x: 47, y: 17, width: 250, height: 150)
        let xAxis = ChartAxisX(first: 1000, last: 2000, firstScreen: plotFrame.minX, lastScreen: plotFrame.maxX)
        let yAxis = ChartAxisY(first: 40, last: 200, firstScreen: plotFrame.maxY, lastScreen: plotFrame.minY)
        let layer = GlucoseRangeBandLayer(xAxis: xAxis, yAxis: yAxis, range: 80...145,
                                         lowerLabel: "80", upperLabel: "145", rangeDescription: "80 to 145 mg/dL")
        let chart = Chart(frame: CGRect(x: 0, y: 0, width: 320, height: 200),
                          innerFrame: plotFrame, settings: ChartSettings(), layers: [layer])
        let band = try XCTUnwrap(chart.contentView.subviews.compactMap { $0 as? GlucoseRangeBandView }.first)
        let frame = band.convert(band.bounds, to: chart.view)
        XCTAssertEqual(frame.minX, xAxis.screenLocForScalar(xAxis.first), accuracy: 0.001)
        XCTAssertEqual(frame.maxX, xAxis.screenLocForScalar(xAxis.last), accuracy: 0.001)
        XCTAssertEqual(frame.minY + band.bandRect.minY, yAxis.screenLocForScalar(145), accuracy: 0.001)
        XCTAssertEqual(frame.minY + band.bandRect.maxY, yAxis.screenLocForScalar(80), accuracy: 0.001)
    }

    func testScheduledTargetsCoverExactNonHourlyAxisBounds() throws {
        let schedule = try XCTUnwrap(GlucoseRangeSchedule(
            unit: .milligramsPerDeciliter,
            dailyItems: [
                RepeatingScheduleValue(startTime: 0, value: DoubleRange(minValue: 90, maxValue: 100)),
                RepeatingScheduleValue(startTime: 12 * 3600, value: DoubleRange(minValue: 100, maxValue: 110))
            ], timeZone: TimeZone(secondsFromGMT: 0)
        ))
        for hours in [1.0, 3, 6, 12, 24] {
            let start = Date(timeIntervalSince1970: 1_700_000_017)
            let end = start.addingTimeInterval(hours * 3600)
            let values = [start, end].map { ChartAxisValueDate(date: $0, formatter: DateFormatter()) }
            let bars = ChartPoint.barsForGlucoseRangeSchedule(schedule, unit: .milligramsPerDeciliter, xAxisValues: values)
            let coordinates = bars.flatMap { $0.points.map { $0.x.scalar } }
            XCTAssertEqual(try XCTUnwrap(coordinates.min()), values[0].scalar, accuracy: 0.001)
            XCTAssertEqual(try XCTUnwrap(coordinates.max()), values[1].scalar, accuracy: 0.001)
            XCTAssertTrue(coordinates.allSatisfy { $0 >= values[0].scalar && $0 <= values[1].scalar })
        }
    }

    func testOverrideTargetIsClampedAtBothAxisEndpoints() {
        let start = Date(timeIntervalSince1970: 1_700_000_017)
        let end = start.addingTimeInterval(3600)
        let values = [start, end].map { ChartAxisValueDate(date: $0, formatter: DateFormatter()) }
        let settings = TemporaryScheduleOverrideSettings(unit: .milligramsPerDeciliter,
                                                        targetRange: DoubleRange(minValue: 110, maxValue: 130),
                                                        insulinNeedsScaleFactor: nil)
        let spanning = TemporaryScheduleOverride(context: .custom, settings: settings,
                                                startDate: start.addingTimeInterval(-3600), duration: .finite(3 * 3600),
                                                enactTrigger: .local, syncIdentifier: UUID())
        let points = ChartPoint.pointsForGlucoseRangeScheduleOverride(spanning, unit: .milligramsPerDeciliter, xAxisValues: values)
        XCTAssertEqual(points.count, 4)
        XCTAssertEqual(points.map { $0.x.scalar }.min(), values[0].scalar)
        XCTAssertEqual(points.map { $0.x.scalar }.max(), values[1].scalar)

        let expired = TemporaryScheduleOverride(context: .custom, settings: settings,
                                               startDate: start.addingTimeInterval(-7200), duration: .finite(3600),
                                               enactTrigger: .local, syncIdentifier: UUID())
        XCTAssertTrue(ChartPoint.pointsForGlucoseRangeScheduleOverride(expired, unit: .milligramsPerDeciliter, xAxisValues: values).isEmpty)
        let future = TemporaryScheduleOverride(context: .custom, settings: settings,
                                              startDate: end.addingTimeInterval(3600), duration: .finite(3600),
                                              enactTrigger: .local, syncIdentifier: UUID())
        XCTAssertTrue(ChartPoint.pointsForGlucoseRangeScheduleOverride(future, unit: .milligramsPerDeciliter, xAxisValues: values).isEmpty)
    }

    func testFillSpansTheEntirePlotWidth() {
        let view = GlucoseRangeBandView(frame: CGRect(x: 35, y: 12, width: 300, height: 180),
                                       upperY: 40, lowerY: 120, upperLabel: "145", lowerLabel: "80")
        XCTAssertEqual(view.bandRect, CGRect(x: 0, y: 40, width: 300, height: 80))
        XCTAssertFalse(view.isUserInteractionEnabled)
    }

    func testOutOfBoundsFillIsClippedAndBoundaryLabelsAreHidden() {
        let view = GlucoseRangeBandView(frame: CGRect(x: 0, y: 0, width: 300, height: 180),
                                       upperY: -20, lowerY: 200, upperLabel: "300", lowerLabel: "20")
        view.layoutIfNeeded()
        XCTAssertEqual(view.bandRect, view.bounds)
        XCTAssertTrue(view.subviews.allSatisfy { $0.isHidden })
    }

    func testCompletelyOutOfBoundsRangeDoesNotFillThePlot() {
        let view = GlucoseRangeBandView(frame: CGRect(x: 0, y: 0, width: 300, height: 180),
                                       upperY: -100, lowerY: -20, upperLabel: "400", lowerLabel: "300")
        XCTAssertTrue(view.bandRect.isNull)
    }

    func testBoundaryLabelsFitInsideNarrowPlot() {
        let view = GlucoseRangeBandView(frame: CGRect(x: 0, y: 0, width: 220, height: 100),
                                       upperY: 1, lowerY: 4, upperLabel: "8.1", lowerLabel: "8.0")
        view.layoutIfNeeded()
        let labels = view.subviews.filter { !$0.isHidden }
        XCTAssertFalse(labels.isEmpty)
        XCTAssertTrue(labels.allSatisfy { view.bounds.contains($0.frame) })
        if labels.count == 2 {
            XCTAssertFalse(labels[0].frame.intersects(labels[1].frame))
        }
    }
}
