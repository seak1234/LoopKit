import XCTest
import UIKit
import SwiftCharts
@testable import LoopKitUI

class ChartViewLifecycleTests: XCTestCase {
    func testOutgoingCellCannotRemoveChartFromReplacementCell() {
        let frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        let chart = UIView(frame: frame)
        let outgoing = ChartContainerView(frame: frame)
        let incoming = ChartContainerView(frame: frame)
        outgoing.chartGenerator = { _ in chart }
        incoming.chartGenerator = { _ in chart }

        outgoing.layoutIfNeeded()
        incoming.layoutIfNeeded()
        XCTAssertTrue(chart.superview === incoming)

        outgoing.setNeedsLayout()
        outgoing.layoutIfNeeded()
        XCTAssertTrue(chart.superview === incoming)

        // Row reloads can reuse or refresh the outgoing cell after the cached
        // chart has already been attached to its replacement.
        outgoing.chartGenerator = nil
        XCTAssertTrue(chart.superview === incoming)
        outgoing.reloadChart()
        XCTAssertTrue(chart.superview === incoming)
    }

    func testReloadingOutgoingChartDoesNotDetachReplacement() {
        let frame = CGRect(x: 0, y: 0, width: 320, height: 180)
        let chart = UIView(frame: frame)
        let outgoing = ChartContainerView(frame: frame)
        let incoming = ChartContainerView(frame: frame)
        outgoing.chartGenerator = { _ in chart }
        incoming.chartGenerator = { _ in chart }
        outgoing.layoutIfNeeded()
        incoming.layoutIfNeeded()

        outgoing.reloadChart()
        XCTAssertTrue(chart.superview === incoming)
    }

    func testChartRegeneratesAfterCollapsedHeightAndDataRefresh() {
        let container = ChartContainerView(frame: CGRect(x: 0, y: 0, width: 320, height: 180))
        var generation = 0
        container.chartGenerator = { frame in
            generation += 1
            let chart = UIView(frame: frame)
            chart.tag = generation
            return chart
        }
        container.layoutIfNeeded()
        XCTAssertEqual(container.subviews.first?.tag, 1)

        container.frame.size.height = 40
        container.reloadChart()
        container.layoutIfNeeded()
        XCTAssertTrue(container.subviews.isEmpty)
        container.frame.size.height = 180
        container.setNeedsLayout()
        container.layoutIfNeeded()
        XCTAssertEqual(container.subviews.first?.tag, 2)
    }

    func testOnlyActiveChartTouchesHideHeaders() {
        let controller = TestChartsController()
        controller.loadViewIfNeeded()
        controller.visible = true
        let gesture = TestGestureRecognizer()
        controller.charts.gestureRecognizer = gesture

        for state in [UIGestureRecognizer.State.possible, .ended, .cancelled, .failed] {
            gesture.simulatedState = state
            XCTAssertEqual(controller.chartHeaderAlpha, 1, "Unexpected hidden header for \(state)")
        }
        for state in [UIGestureRecognizer.State.began, .changed] {
            gesture.simulatedState = state
            XCTAssertEqual(controller.chartHeaderAlpha, 0)
        }
        controller.active = false
        XCTAssertEqual(controller.chartHeaderAlpha, 1)
        controller.active = true
        controller.visible = false
        XCTAssertEqual(controller.chartHeaderAlpha, 1)
        controller.charts.gestureRecognizer = nil
        controller.visible = true
        XCTAssertEqual(controller.chartHeaderAlpha, 1)
    }

    func testReuseRestoresHeaderOpacity() {
        let cell = makeCell()
        cell.setAlpha(alpha: 0)
        cell.prepareForReuse()
        XCTAssertEqual(cell.titleLabel?.alpha, 1)
        XCTAssertEqual(cell.subtitleLabel?.alpha, 1)
        XCTAssertEqual(cell.historyDurationSelector.alpha, 1)
    }

    func testDisplayingPrefetchedCellRestoresHeaderAfterCancelledTouch() {
        let controller = TestChartsController()
        controller.loadViewIfNeeded()
        controller.visible = true
        let gesture = TestGestureRecognizer()
        gesture.simulatedState = .cancelled
        controller.charts.gestureRecognizer = gesture
        let cell = makeCell()
        cell.setAlpha(alpha: 0)

        controller.tableView(controller.tableView, willDisplay: cell, forRowAt: IndexPath(row: 0, section: 0))
        XCTAssertEqual(cell.titleLabel?.alpha, 1)
        XCTAssertEqual(cell.subtitleLabel?.alpha, 1)
    }

    private func makeCell() -> ChartTableViewCell {
        let cell = ChartTableViewCell(style: .default, reuseIdentifier: nil)
        let chart = ChartContainerView()
        let title = UILabel()
        let subtitle = UILabel()
        cell.contentView.addSubview(chart)
        cell.contentView.addSubview(title)
        cell.contentView.addSubview(subtitle)
        cell.chartContentView = chart
        cell.titleLabel = title
        cell.subtitleLabel = subtitle
        return cell
    }
}

private class TestGestureRecognizer: UIGestureRecognizer {
    var simulatedState: UIGestureRecognizer.State = .possible
    override var state: UIGestureRecognizer.State {
        get { simulatedState }
        set { simulatedState = newValue }
    }
}

private class TestChartsController: ChartsTableViewController {
    override func createChartsManager() -> ChartsManager {
        let colors = ChartColorPalette(axisLine: .gray, axisLabel: .gray, grid: .gray,
                                       glucoseTint: .blue, insulinTint: .orange, carbTint: .green)
        return ChartsManager(colors: colors, settings: ChartSettings(), charts: [], traitCollection: UITraitCollection())
    }
}
