//
//  StatusChartHighlightLayer.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/28/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import Foundation
import SwiftCharts
import UIKit

private final class SelectionGuideView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let strokeColor: UIColor

    init(color: UIColor) {
        self.strokeColor = color
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        shapeLayer.lineWidth = 1
        shapeLayer.lineDashPattern = [3, 4]
        shapeLayer.fillColor = nil
        layer.addSublayer(shapeLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        shapeLayer.strokeColor = strokeColor.resolvedColor(with: traitCollection).cgColor
        let path = CGMutablePath()
        path.move(to: CGPoint(x: bounds.midX, y: bounds.minY))
        path.addLine(to: CGPoint(x: bounds.midX, y: bounds.maxY))
        shapeLayer.path = path
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        shapeLayer.strokeColor = strokeColor.resolvedColor(with: traitCollection).cgColor
    }
}

final class ChartPointsTouchHighlightLayerViewCache {
    private lazy var containerView = UIView(frame: .zero)

    private lazy var xAxisOverlayView = UIView()

    private lazy var selectionGuideView: SelectionGuideView = {
        let color = self.selectionGuideColor ?? self.axisLabelSettings.fontColor.withAlphaComponent(0.35)
        return SelectionGuideView(color: color)
    }()

    private lazy var glowPoint = ChartPointEllipseView(center: .zero, diameter: 16)

    private lazy var dotPoint = ChartPointEllipseView(center: .zero, diameter: 9)

    private lazy var innerDotPoint = ChartPointEllipseView(center: .zero, diameter: 5)

    private lazy var labelY: UILabel = {
        let label = UILabel()
        label.font = UIFont.monospacedDigitSystemFont(ofSize: 15, weight: UIFont.Weight.bold)

        return label
    }()

    private lazy var labelX: UILabel = {
        let label = UILabel()
        label.font = self.axisLabelSettings.font
        label.textColor = self.axisLabelSettings.fontColor

        return label
    }()

    private let axisLabelSettings: ChartLabelSettings
    private let tintColor: UIColor
    private let selectionGuideColor: UIColor?
    private let onHighlightStateChange: ((_ isHighlighting: Bool) -> Void)?
    private var isHighlighting = false

    private let selectionFeedback = UISelectionFeedbackGenerator()
    private var isDirectlyInteracted = false
    private var lastHighlightedPointIndex: Int?

    private(set) var highlightLayer: ChartPointsTouchHighlightLayer<ChartPoint, UIView>!

    init(
        xAxisLayer: ChartAxisLayer,
        yAxisLayer: ChartAxisLayer,
        axisLabelSettings: ChartLabelSettings,
        chartPoints: [ChartPoint],
        tintColor: UIColor,
        selectionGuideColor: UIColor? = nil,
        gestureRecognizer: UIGestureRecognizer? = nil,
        onHighlightStateChange: ((_ isHighlighting: Bool) -> Void)? = nil,
        onCompleteHighlight: (() -> Void)? = nil
    ) {
        self.axisLabelSettings = axisLabelSettings
        self.tintColor = tintColor
        self.selectionGuideColor = selectionGuideColor
        self.onHighlightStateChange = onHighlightStateChange

        if let gestureRecognizer = gestureRecognizer {
            gestureRecognizer.addTarget(self, action: #selector(handleGesture(_:)))
        }

        highlightLayer = ChartPointsTouchHighlightLayer(
            xAxis: xAxisLayer.axis,
            yAxis: yAxisLayer.axis,
            chartPoints: chartPoints,
            gestureRecognizer: gestureRecognizer,
            onCompleteHighlight: { [weak self] in
                self?.isDirectlyInteracted = false
                self?.lastHighlightedPointIndex = nil
                self?.setHighlightActive(false, animated: false)
                onCompleteHighlight?()
            },
            modelFilter: { (screenLoc, chartPointModels) -> ChartPointLayerModel<ChartPoint>? in
                if let index = chartPointModels.map({ $0.screenLoc.x }).findClosestElementIndex(matching: screenLoc.x) {
                    return chartPointModels[index]
                } else {
                    return nil
                }
            },
            viewGenerator: { [weak self] (chartPointModel, layer, chart) -> UIView? in
                guard let strongSelf = self else {
                    return nil
                }

                if strongSelf.isDirectlyInteracted {
                    if let lastIndex = strongSelf.lastHighlightedPointIndex,
                       lastIndex != chartPointModel.index {
                        strongSelf.selectionFeedback.selectionChanged()
                        strongSelf.selectionFeedback.prepare()
                    }
                    strongSelf.lastHighlightedPointIndex = chartPointModel.index
                }

                if !strongSelf.isHighlighting {
                    strongSelf.setHighlightActive(true, animated: false)
                }

                if let layerView = strongSelf.highlightLayer?.view {
                    if layerView.superview != chart.containerView {
                        chart.containerView.addSubview(layerView)
                    }
                    layerView.frame = chart.containerView.bounds
                    layerView.layer.zPosition = 2000
                    chart.containerView.bringSubviewToFront(layerView)
                }

                let containerView = strongSelf.containerView
                containerView.frame = chart.containerView.bounds
                containerView.layer.zPosition = 2000
                containerView.alpha = 1  // This is animated to 0 when touch last ended

                let selectionGuideView = strongSelf.selectionGuideView
                selectionGuideView.frame = CGRect(
                    x: chartPointModel.screenLoc.x - 0.5,
                    y: containerView.bounds.minY,
                    width: 1,
                    height: containerView.bounds.height
                )
                selectionGuideView.layer.zPosition = 1999
                selectionGuideView.setNeedsLayout()
                if selectionGuideView.superview == nil {
                    containerView.insertSubview(selectionGuideView, at: 0)
                }

                let xAxisOverlayView = strongSelf.xAxisOverlayView
                xAxisOverlayView.layer.zPosition = 2000
                if xAxisOverlayView.superview == nil {
                    xAxisOverlayView.frame = CGRect(
                        origin: CGPoint(x: containerView.bounds.minX,
                                        y: containerView.bounds.maxY + 1), // Don't clip X line
                        size: xAxisLayer.frame.size
                    )
                    xAxisOverlayView.backgroundColor = .systemBackground
                    xAxisOverlayView.isOpaque = true
                    containerView.addSubview(xAxisOverlayView)
                }

                let glowPoint = strongSelf.glowPoint
                glowPoint.center = chartPointModel.screenLoc
                glowPoint.layer.zPosition = 2001
                if glowPoint.superview == nil {
                    glowPoint.fillColor = tintColor.withAlphaComponent(0.25)
                    containerView.addSubview(glowPoint)
                }

                let dotPoint = strongSelf.dotPoint
                dotPoint.center = chartPointModel.screenLoc
                dotPoint.layer.zPosition = 2002
                if dotPoint.superview == nil {
                    dotPoint.fillColor = tintColor
                    containerView.addSubview(dotPoint)
                }

                let innerDotPoint = strongSelf.innerDotPoint
                innerDotPoint.center = chartPointModel.screenLoc
                innerDotPoint.layer.zPosition = 2003
                if innerDotPoint.superview == nil {
                    innerDotPoint.fillColor = .white
                    containerView.addSubview(innerDotPoint)
                }

                containerView.bringSubviewToFront(selectionGuideView)
                containerView.bringSubviewToFront(xAxisOverlayView)
                containerView.bringSubviewToFront(glowPoint)
                containerView.bringSubviewToFront(dotPoint)
                containerView.bringSubviewToFront(innerDotPoint)

                if let text = chartPointModel.chartPoint.y.labels.first?.text {
                    let label = strongSelf.labelY

                    label.text = text
                    label.sizeToFit()
                    label.center.y = containerView.frame.minY - 21
                    label.center.x = chartPointModel.screenLoc.x
                    label.frame.origin.x = min(max(label.frame.origin.x, containerView.bounds.minX), containerView.bounds.maxX - label.frame.size.width)
                    label.frame.origin.makeIntegralInPlaceWithDisplayScale(chart.view.traitCollection.displayScale)
                    label.layer.zPosition = 2004

                    if label.superview == nil {
                        label.textColor = tintColor

                        containerView.addSubview(label)
                    }
                    containerView.bringSubviewToFront(label)
                }

                if let text = chartPointModel.chartPoint.x.labels.first?.text {
                    let label = strongSelf.labelX
                    label.text = text
                    label.sizeToFit()
                    label.center = CGPoint(x: chartPointModel.screenLoc.x, y: xAxisOverlayView.center.y)
                    label.frame.origin.makeIntegralInPlaceWithDisplayScale(chart.view.traitCollection.displayScale)
                    label.layer.zPosition = 2004

                    if label.superview == nil {
                        containerView.addSubview(label)
                    }
                    containerView.bringSubviewToFront(label)
                }
                
                return containerView
            }
        )
    }

    @objc private func handleGesture(_ gestureRecognizer: UIGestureRecognizer) {
        switch gestureRecognizer.state {
        case .began:
            if let view = highlightLayer?.view, view.window != nil {
                let loc = gestureRecognizer.location(in: view)
                isDirectlyInteracted = view.bounds.insetBy(dx: 0, dy: -20).contains(loc)
            } else {
                isDirectlyInteracted = true
            }

            if isDirectlyInteracted {
                selectionFeedback.prepare()
            }
            setHighlightActive(true, animated: true)
        case .cancelled, .ended, .failed:
            isDirectlyInteracted = false
            lastHighlightedPointIndex = nil
            setHighlightActive(false, animated: true)
        default:
            break
        }
    }

    private func setHighlightActive(_ active: Bool, animated: Bool) {
        guard isHighlighting != active else { return }
        isHighlighting = active

        if animated {
            let duration: TimeInterval = active ? 0.2 : 0.5
            let delay: TimeInterval = active ? 0 : 1.0
            UIView.animate(withDuration: duration, delay: delay, options: [.beginFromCurrentState], animations: {
                self.onHighlightStateChange?(active)
            }, completion: nil)
        } else {
            self.onHighlightStateChange?(active)
        }
    }
}
