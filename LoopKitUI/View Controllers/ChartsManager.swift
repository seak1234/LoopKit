//
//  Chart.swift
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


open class ChartsManager {

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        let dateFormat = DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: Locale.current)!
        let isAmPmTimeFormat = dateFormat.firstIndex(of: "a") != nil
        formatter.dateFormat = isAmPmTimeFormat
            ? "h a"
            : "H:mm"
        return formatter
    }()

    public init(
        colors: ChartColorPalette,
        settings: ChartSettings,
        axisLabelFont: UIFont = .systemFont(ofSize: 14), // caption1, but hard-coded until axis can scale with type preference
        charts: [ChartProviding],
        traitCollection: UITraitCollection
    ) {
        self.colors = colors
        self.chartSettings = settings
        self.charts = charts
        self.traitCollection = traitCollection
        self.chartsCache = Array(repeating: nil, count: charts.count)

        axisLabelSettings = ChartLabelSettings(font: axisLabelFont, fontColor: colors.axisLabel)

        guideLinesLayerSettings = ChartGuideLinesLayerSettings(linesColor: colors.grid, linesWidth: 0.6)
    }

    // MARK: - Configuration

    private let colors: ChartColorPalette

    private let chartSettings: ChartSettings

    private let labelsWidthY: CGFloat = 30

    public let charts: [ChartProviding]

    /// The amount of horizontal space reserved for fixed margins
    public var fixedHorizontalMargin: CGFloat {
        return chartSettings.leading + chartSettings.trailing + labelsWidthY + chartSettings.labelsToAxisSpacingY
    }

    private let axisLabelSettings: ChartLabelSettings

    private let guideLinesLayerSettings: ChartGuideLinesLayerSettings

    public var gestureRecognizer: UIGestureRecognizer?

    // MARK: - UITraitEnvironment

    public var traitCollection: UITraitCollection

    public func didReceiveMemoryWarning() {

        for chart in charts {
            chart.didReceiveMemoryWarning()
        }

        xAxisValues = nil
    }

    // MARK: - Data

    /// The earliest date on the X-axis
    public var startDate = Date() {
        didSet {
            if startDate != oldValue {
                xAxisValues = nil

                // Set a new minimum end date
                endDate = startDate.addingTimeInterval(.hours(3))
            }
        }
    }

    /// The latest date on the X-axis
    private var endDate = Date() {
        didSet {
            if endDate != oldValue {
                xAxisValues = nil
            }
        }
    }

    /// The latest allowed date on the X-axis
    public var maxEndDate = Date.distantFuture {
        didSet {
            endDate = min(endDate, maxEndDate)
        }
    }

    /// Updates the endDate using a new candidate date
    ///
    /// Dates are rounded up to the next hour.
    ///
    /// - Parameter date: The new candidate date
    public func updateEndDate(_ date: Date) {
        if date > endDate {
            let components = DateComponents(minute: 0)
            endDate = min(
                maxEndDate,
                Calendar.current.nextDate(
                    after: date,
                    matching: components,
                    matchingPolicy: .strict,
                    direction: .forward
                ) ?? date
            )
        }
    }

    // MARK: - State

    private var xAxisValues: [ChartAxisValue]? {
        didSet {
            if let xAxisValues = xAxisValues, xAxisValues.count > 1 {
                xAxisModel = ChartAxisModel(axisValues: xAxisValues, lineColor: colors.axisLine, labelSpaceReservationMode: .fixed(20))
            } else {
                xAxisModel = nil
            }

            chartsCache.replaceAllElements(with: nil)
        }
    }

    private var xAxisModel: ChartAxisModel?

    private var chartsCache: [Chart?]

    // MARK: - Generators

    public func chart(atIndex index: Int, frame: CGRect) -> Chart? {
        if let chart = chartsCache[index], chart.frame != frame {
            chartsCache[index] = nil
        }

        if chartsCache[index] == nil, let xAxisModel = xAxisModel, let xAxisValues = xAxisValues {
            chartsCache[index] = charts[index].generate(withFrame: frame, xAxisModel: xAxisModel, xAxisValues: xAxisValues, axisLabelSettings: axisLabelSettings, guideLinesLayerSettings: guideLinesLayerSettings, colors: colors, chartSettings: chartSettings, labelsWidthY: labelsWidthY, gestureRecognizer: gestureRecognizer, traitCollection: traitCollection)
        }

        return chartsCache[index]
    }

    public func invalidateChart(atIndex index: Int) {
        chartsCache[index] = nil
    }

    // MARK: - Shared Axis

    private func generateXAxisValues() {
        if let endDate = charts.compactMap({ $0.endDate }).max() {
            updateEndDate(endDate)
        }

        let totalHours = ceil(endDate.timeIntervalSince(startDate).hours)
        guard totalHours > 0 else {
            self.xAxisValues = []
            return
        }

        let hourStep: Double
        if totalHours <= 9 {
            hourStep = 1
        } else if totalHours <= 14 {
            hourStep = 2
        } else if totalHours <= 20 {
            hourStep = 3
        } else {
            hourStep = 6
        }

        let firstAxisValue = ChartAxisValueDate(
            date: startDate,
            formatter: timeFormatter,
            labelSettings: axisLabelSettings
        )
        firstAxisValue.hidden = true

        let lastAxisValue = ChartAxisValueDate(
            date: endDate,
            formatter: timeFormatter,
            labelSettings: axisLabelSettings
        )
        lastAxisValue.hidden = true

        var values: [ChartAxisValue] = [firstAxisValue]

        let calendar = Calendar.current
        let intStep = Int(hourStep)
        var currentDate: Date
        if let nextHour = calendar.nextDate(after: startDate, matching: DateComponents(minute: 0), matchingPolicy: .strict, direction: .forward) {
            if intStep > 1 {
                let hour = calendar.component(.hour, from: nextHour)
                let remainder = hour % intStep
                if remainder == 0 {
                    currentDate = nextHour
                } else {
                    let hoursToAdd = intStep - remainder
                    currentDate = calendar.date(byAdding: .hour, value: hoursToAdd, to: nextHour) ?? nextHour
                }
            } else {
                currentDate = nextHour
            }
        } else {
            currentDate = startDate.addingTimeInterval(.hours(hourStep))
        }

        let minSpacingFromStart = TimeInterval(hours: hourStep * 0.35)
        if currentDate.timeIntervalSince(startDate) < minSpacingFromStart {
            currentDate = currentDate.addingTimeInterval(.hours(hourStep))
        }

        let minSpacingFromEnd = TimeInterval(hours: hourStep * 0.5)
        while currentDate < endDate.addingTimeInterval(-minSpacingFromEnd) {
            let axisValue = ChartAxisValueDate(
                date: currentDate,
                formatter: timeFormatter,
                labelSettings: axisLabelSettings
            )
            values.append(axisValue)
            currentDate = currentDate.addingTimeInterval(.hours(hourStep))
        }
        values.append(lastAxisValue)

        self.xAxisValues = values
    }

    /// Runs any necessary steps before rendering charts
    public func prerender() {
        if xAxisValues == nil {
            generateXAxisValues()
        }
    }
}

fileprivate extension Array {
    mutating func replaceAllElements(with element: Element) {
        self = Array(repeating: element, count: count)
    }
}

public protocol ChartProviding {
    /// Instructs the chart to clear its non-critical resources like caches
    func didReceiveMemoryWarning()

    /// The last date represented in the chart data
    var endDate: Date? { get }

    /// Creates a chart from the current data
    ///
    /// - Returns: A new chart object
    func generate(withFrame frame: CGRect,
        xAxisModel: ChartAxisModel,
        xAxisValues: [ChartAxisValue],
        axisLabelSettings: ChartLabelSettings,
        guideLinesLayerSettings: ChartGuideLinesLayerSettings,
        colors: ChartColorPalette,
        chartSettings: ChartSettings,
        labelsWidthY: CGFloat,
        gestureRecognizer: UIGestureRecognizer?,
        traitCollection: UITraitCollection
    ) -> Chart
}
