import UIKit
import SwiftCharts

/// A presentation-only overlay. Its bounds never participate in chart scaling
/// or prediction clamping, and it does not register any touch handlers.
final class GlucoseRangeBandLayer: ChartCoordsSpaceLayer {
    private let range: ClosedRange<Double>
    private let lowerLabel: String
    private let upperLabel: String
    private let rangeDescription: String

    init(xAxis: ChartAxis, yAxis: ChartAxis,
         range: ClosedRange<Double>, lowerLabel: String, upperLabel: String, rangeDescription: String) {
        self.range = range
        self.lowerLabel = lowerLabel
        self.upperLabel = upperLabel
        self.rangeDescription = rangeDescription
        super.init(xAxis: xAxis, yAxis: yAxis)
    }

    override func chartInitialized(chart: Chart) {
        super.chartInitialized(chart: chart)
        // addSubview uses chart.contentView coordinates, whose origin already
        // excludes the axis labels and chart margins.
        let plotFrame = plotFrameInContentCoordinates
        let upperY = modelLocToScreenLoc(y: range.upperBound) - plotFrame.minY
        let lowerY = modelLocToScreenLoc(y: range.lowerBound) - plotFrame.minY
        guard upperY.isFinite, lowerY.isFinite else { return }
        let view = GlucoseRangeBandView(frame: plotFrame, upperY: upperY, lowerY: lowerY,
                                        upperLabel: upperLabel, lowerLabel: lowerLabel)
        view.accessibilityLabel = rangeDescription
        chart.addSubview(view)
    }
}

final class GlucoseRangeBandView: UIView {
    private let upperY: CGFloat
    private let lowerY: CGFloat
    private let upperLabel = UILabel()
    private let lowerLabel = UILabel()

    private static let sage = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.56, green: 0.78, blue: 0.66, alpha: 1)
            : UIColor(red: 0.32, green: 0.51, blue: 0.42, alpha: 1)
    }

    init(frame: CGRect, upperY: CGFloat, lowerY: CGFloat, upperLabel: String, lowerLabel: String) {
        self.upperY = upperY
        self.lowerY = lowerY
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        clipsToBounds = true
        isAccessibilityElement = true

        for (label, text) in [(self.upperLabel, upperLabel), (self.lowerLabel, lowerLabel)] {
            label.text = text
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
            label.textColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? Self.sage.resolvedColor(with: traits)
                    : UIColor(red: 0.25, green: 0.42, blue: 0.33, alpha: 1)
            }
            label.isAccessibilityElement = false
            addSubview(label)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Clip the fill instead of expanding the y-axis to accommodate this preference.
    var bandRect: CGRect {
        CGRect(x: 0, y: upperY, width: bounds.width, height: max(0, lowerY - upperY)).intersection(bounds)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        for (label, y, above) in [(upperLabel, upperY, true), (lowerLabel, lowerY, false)] {
            label.sizeToFit()
            let height = label.bounds.height
            let proposedY = above ? y - height - 2 : y + 2
            label.frame.origin = CGPoint(x: max(0, bounds.width - label.bounds.width - 4),
                                         y: min(max(0, proposedY), max(0, bounds.height - height)))
            label.isHidden = y < 0 || y > bounds.height
        }
        if !upperLabel.isHidden && !lowerLabel.isHidden,
           upperLabel.frame.insetBy(dx: 0, dy: -2).intersects(lowerLabel.frame) {
            lowerLabel.isHidden = true
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let color = Self.sage.resolvedColor(with: traitCollection)
        context.saveGState()
        context.clip(to: bounds)
        context.setFillColor(color.withAlphaComponent(traitCollection.userInterfaceStyle == .dark ? 0.18 : 0.12).cgColor)
        if !bandRect.isNull { context.fill(bandRect) }
        context.setStrokeColor(color.withAlphaComponent(0.55).cgColor)
        context.setLineWidth(1)
        context.setLineDash(phase: 0, lengths: [3, 4])
        for y in [upperY, lowerY] where y >= 0 && y <= bounds.height {
            context.move(to: CGPoint(x: 0, y: y))
            context.addLine(to: CGPoint(x: bounds.width, y: y))
        }
        context.strokePath()
        context.restoreGState()
    }
}
