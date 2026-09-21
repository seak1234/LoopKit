//
//  ChartTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

private enum DashboardCardTheme {
    static let coral = UIColor { _ in
        UIColor(red: 232 / 255, green: 130 / 255, blue: 136 / 255, alpha: 1.0) // #E88288
    }
    static let ink = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.94, blue: 0.92, alpha: 1.0)
            : UIColor(red: 0.25, green: 0.14, blue: 0.15, alpha: 1.0)
    }
    static let mutedInk = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.82, green: 0.68, blue: 0.66, alpha: 1.0)
            : UIColor(red: 0.52, green: 0.36, blue: 0.37, alpha: 1.0)
    }
    static let surface = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.10, blue: 0.11, alpha: 1.0)
            : UIColor(red: 1.00, green: 0.985, blue: 0.975, alpha: 1.0)
    }
    static let border = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.10)
            : UIColor(red: 0.95, green: 0.84, blue: 0.81, alpha: 1.0)
    }
}

private extension UIFont {
    static func dashboardRounded(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let font = UIFont.systemFont(ofSize: size, weight: weight)
        guard let descriptor = font.fontDescriptor.withDesign(.rounded) else { return font }
        return UIFont(descriptor: descriptor, size: size)
    }

    static func dashboardRoundedDigits(ofSize size: CGFloat, weight: UIFont.Weight) -> UIFont {
        let font = UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        guard let descriptor = font.fontDescriptor.withDesign(.rounded) else { return font }
        return UIFont(descriptor: descriptor, size: size)
    }
}


public final class ChartTableViewCell: UITableViewCell {

    @IBOutlet weak var chartContentView: ChartContainerView!

    @IBOutlet weak var titleLabel: UILabel?

    @IBOutlet weak var subtitleLabel: UILabel?
   
    @IBOutlet weak var rightArrowHint: UIImageView? {
        didSet {
            rightArrowHint?.isHidden = !doesNavigate
        }
    }

    public var doesNavigate: Bool = true {
        didSet {
            rightArrowHint?.isHidden = !doesNavigate
            collapsedChevronView.isHidden = !doesNavigate
            navigationButton.isHidden = !doesNavigate
            setNeedsLayout()
        }
    }

    /// Invoked when the value-and-chevron area in the card header is tapped.
    public var onNavigate: (() -> Void)?

    private lazy var navigationButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .clear
        button.accessibilityLabel = NSLocalizedString("Show Details", comment: "Accessibility label for opening chart details")
        button.addTarget(self, action: #selector(navigationButtonTapped), for: .touchUpInside)
        return button
    }()


    public private(set) lazy var historyDurationSelector: HistoryDurationSelectorControl = {
        let selector = HistoryDurationSelectorControl()
        selector.isHidden = true
        return selector
    }()

    private var historyDurationSelectorConstraints: [NSLayoutConstraint] = []

    private lazy var collapsedSummaryView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true

        view.addSubview(collapsedIconBackgroundView)
        view.addSubview(collapsedIconView)
        view.addSubview(collapsedTextStack)
        view.addSubview(collapsedValueLabel)
        view.addSubview(collapsedChevronView)

        NSLayoutConstraint.activate([
            collapsedIconBackgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            collapsedIconBackgroundView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            collapsedIconBackgroundView.widthAnchor.constraint(equalToConstant: 48),
            collapsedIconBackgroundView.heightAnchor.constraint(equalTo: collapsedIconBackgroundView.widthAnchor),

            collapsedIconView.centerXAnchor.constraint(equalTo: collapsedIconBackgroundView.centerXAnchor),
            collapsedIconView.centerYAnchor.constraint(equalTo: collapsedIconBackgroundView.centerYAnchor),
            collapsedIconView.widthAnchor.constraint(equalToConstant: 24),
            collapsedIconView.heightAnchor.constraint(equalToConstant: 24),

            collapsedTextStack.leadingAnchor.constraint(equalTo: collapsedIconBackgroundView.trailingAnchor, constant: 14),
            collapsedTextStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            collapsedTextStack.trailingAnchor.constraint(lessThanOrEqualTo: collapsedValueLabel.leadingAnchor, constant: -10),

            collapsedChevronView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            collapsedChevronView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            collapsedChevronView.widthAnchor.constraint(equalToConstant: 10),

            collapsedValueLabel.trailingAnchor.constraint(equalTo: collapsedChevronView.leadingAnchor, constant: -12),
            collapsedValueLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])

        return view
    }()

    private let collapsedIconBackgroundView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 24
        return view
    }()

    private let collapsedIconView: UIImageView = {
        let view = UIImageView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        return view
    }()

    private let collapsedTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .dashboardRounded(ofSize: 14, weight: .semibold)
        label.textColor = DashboardCardTheme.ink
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.8
        return label
    }()

    private let collapsedDetailLabel: UILabel = {
        let label = UILabel()
        label.font = .dashboardRounded(ofSize: 12, weight: .regular)
        label.textColor = DashboardCardTheme.mutedInk
        return label
    }()

    private lazy var collapsedTextStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [collapsedTitleLabel, collapsedDetailLabel])
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.alignment = .leading
        stack.spacing = 1
        return stack
    }()

    private let collapsedValueLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .dashboardRoundedDigits(ofSize: 20, weight: .bold)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let collapsedChevronView: UIImageView = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)
        let view = UIImageView(image: UIImage(systemName: "chevron.right", withConfiguration: configuration))
        view.translatesAutoresizingMaskIntoConstraints = false
        view.contentMode = .scaleAspectFit
        view.tintColor = DashboardCardTheme.coral
        return view
    }()

    public override func awakeFromNib() {
        super.awakeFromNib()
        setupCardAppearance()
        setupTitleLabelLeadingConstraint()
    }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCardAppearance()
        setupTitleLabelLeadingConstraint()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    private func setupCardAppearance() {
        backgroundColor = .clear
        selectionStyle = .none
        contentView.layer.cornerRadius = 16
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 1
        contentView.addSubview(collapsedSummaryView)
        contentView.addSubview(navigationButton)
        NSLayoutConstraint.activate([
            collapsedSummaryView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collapsedSummaryView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collapsedSummaryView.topAnchor.constraint(equalTo: contentView.topAnchor),
            collapsedSummaryView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        rightArrowHint?.tintColor = DashboardCardTheme.coral
        updateCardColors()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateCardColors()
        historyDurationSelector.updateColors()
        if let attributed = subtitleLabel?.attributedText {
            subtitleLabel?.attributedText = NSAttributedString(attributedString: attributed)
        }
    }

    private func updateCardColors() {
        contentView.backgroundColor = DashboardCardTheme.surface
        contentView.layer.borderColor = DashboardCardTheme.border.resolvedColor(with: traitCollection).cgColor
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let horizontalMargin: CGFloat = 14
        let verticalMargin: CGFloat = 5
        contentView.frame = bounds.inset(by: UIEdgeInsets(top: verticalMargin, left: horizontalMargin, bottom: verticalMargin, right: horizontalMargin))
        layoutNavigationButton()
    }

    private func layoutNavigationButton() {
        guard doesNavigate else {
            navigationButton.isHidden = true
            return
        }

        let valueView: UIView?
        let chevronView: UIView?
        if collapsedSummaryView.isHidden {
            valueView = subtitleLabel
            chevronView = rightArrowHint
        } else {
            valueView = collapsedValueLabel
            chevronView = collapsedChevronView
        }

        guard let valueView, let chevronView else {
            navigationButton.isHidden = true
            return
        }

        let valueFrame = valueView.convert(valueView.bounds, to: contentView)
        let chevronFrame = chevronView.convert(chevronView.bounds, to: contentView)
        let visualFrame = valueFrame.union(chevronFrame)
            .insetBy(dx: -12, dy: -12)
            .intersection(contentView.bounds)

        // Give the value and chevron a generous, predictable hit target. This
        // also keeps the control distinct from the rest of the card, which is
        // reserved for expanding and collapsing the graph.
        let minimumWidth: CGFloat = 132
        let leading = max(contentView.bounds.midX, min(visualFrame.minX, contentView.bounds.maxX - minimumWidth))
        let hitFrame: CGRect
        if collapsedSummaryView.isHidden {
            hitFrame = CGRect(
                x: leading,
                y: 0,
                width: contentView.bounds.maxX - leading,
                height: max(44, visualFrame.maxY)
            )
        } else {
            hitFrame = CGRect(
                x: leading,
                y: 0,
                width: contentView.bounds.maxX - leading,
                height: contentView.bounds.height
            )
        }

        navigationButton.frame = hitFrame
        navigationButton.isHidden = hitFrame.isEmpty
        contentView.bringSubviewToFront(navigationButton)
    }

    @objc private func navigationButtonTapped() {
        onNavigate?()
    }

    private func setupTitleLabelLeadingConstraint() {
        guard let titleLabel = titleLabel else { return }

        for constraint in contentView.constraints {
            if (constraint.firstItem as? UIView) == titleLabel && constraint.firstAttribute == .leading {
                constraint.isActive = false
            }
        }

        titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14).isActive = true
    }

    private var historyDurationLeftSpacer: UILayoutGuide?
    private var historyDurationRightSpacer: UILayoutGuide?

    private func setupHistoryDurationSelector() {
        guard let titleLabel = titleLabel, historyDurationSelector.superview == nil else { return }

        contentView.addSubview(historyDurationSelector)

        let leftSpacer: UILayoutGuide
        if let existing = historyDurationLeftSpacer {
            leftSpacer = existing
        } else {
            leftSpacer = UILayoutGuide()
            contentView.addLayoutGuide(leftSpacer)
            historyDurationLeftSpacer = leftSpacer
        }

        let rightSpacer: UILayoutGuide
        if let existing = historyDurationRightSpacer {
            rightSpacer = existing
        } else {
            rightSpacer = UILayoutGuide()
            contentView.addLayoutGuide(rightSpacer)
            historyDurationRightSpacer = rightSpacer
        }

        var constraints: [NSLayoutConstraint] = [
            historyDurationSelector.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            leftSpacer.leadingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            leftSpacer.trailingAnchor.constraint(equalTo: historyDurationSelector.leadingAnchor),
            leftSpacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 4),
        ]

        if let subtitleLabel = subtitleLabel {
            let equalWidth = leftSpacer.widthAnchor.constraint(equalTo: rightSpacer.widthAnchor)
            equalWidth.priority = UILayoutPriority(999)

            constraints.append(contentsOf: [
                rightSpacer.leadingAnchor.constraint(equalTo: historyDurationSelector.trailingAnchor),
                rightSpacer.trailingAnchor.constraint(equalTo: subtitleLabel.leadingAnchor),
                rightSpacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 4),
                equalWidth
            ])
        } else {
            constraints.append(leftSpacer.widthAnchor.constraint(equalToConstant: 8))
        }

        historyDurationSelectorConstraints = constraints
        NSLayoutConstraint.activate(historyDurationSelectorConstraints)
    }

    public func configureHistoryDurationSelector(selectedHours: Int, onSelect: @escaping (Int) -> Void) {
        setupHistoryDurationSelector()
        historyDurationSelector.selectedHours = selectedHours
        historyDurationSelector.onDurationSelected = onSelect
        historyDurationSelector.isHidden = false
        NSLayoutConstraint.activate(historyDurationSelectorConstraints)
        subtitleLabel?.adjustsFontSizeToFitWidth = true
        subtitleLabel?.minimumScaleFactor = 0.80
    }

    public func hideHistoryDurationSelector() {
        historyDurationSelector.isHidden = true
        historyDurationSelector.onDurationSelected = nil
        NSLayoutConstraint.deactivate(historyDurationSelectorConstraints)
    }

    public func setDotColor(_ color: UIColor?) {
        // No-op: dot indicators next to graph headers removed
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        onNavigate = nil
        doesNavigate = true
        chartContentView.chartGenerator = nil
        hideHistoryDurationSelector()
        titleLabel?.attributedText = nil
        titleLabel?.text = nil
        subtitleLabel?.attributedText = nil
        subtitleLabel?.text = nil
        setExpandedAppearance()
    }

    public func reloadChart() {
        chartContentView.reloadChart()
    }
    
    public func setChartGenerator(generator: ((CGRect) -> UIView?)?) {
        chartContentView.chartGenerator = generator
    }
    
    public func setTitleLabelText(label: String?) {
        guard let label = label else {
            titleLabel?.attributedText = nil
            titleLabel?.text = nil
            return
        }
        let uppercaseText = label.uppercased()
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.dashboardRounded(ofSize: 12, weight: .bold),
            .kern: 1.2,
            .foregroundColor: DashboardCardTheme.ink
        ]
        titleLabel?.attributedText = NSAttributedString(string: uppercaseText, attributes: attributes)
    }
    
    public func removeTitleLabelText() {
        titleLabel?.attributedText = nil
        titleLabel?.text?.removeAll()
    }
    
    public func setSubtitleLabel(label: String?) {
        guard let label = label else {
            subtitleLabel?.attributedText = nil
            subtitleLabel?.text = nil
            return
        }
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.dashboardRoundedDigits(ofSize: 13, weight: .semibold),
            .foregroundColor: DashboardCardTheme.mutedInk
        ]
        subtitleLabel?.attributedText = NSAttributedString(string: label, attributes: attributes)
    }

    public func setAttributedSubtitleLabel(_ attributedString: NSAttributedString?) {
        subtitleLabel?.attributedText = attributedString
    }

    public func setCollapsedAppearance(iconSystemName: String, title: String, detail: String, value: String?, tintColor: UIColor) {
        chartContentView.isHidden = true
        titleLabel?.isHidden = true
        subtitleLabel?.isHidden = true
        rightArrowHint?.isHidden = true
        historyDurationSelector.isHidden = true

        collapsedIconView.image = UIImage(systemName: iconSystemName)
        collapsedIconView.tintColor = tintColor
        collapsedIconBackgroundView.backgroundColor = tintColor.withAlphaComponent(0.12)
        collapsedTitleLabel.text = title.uppercased()
        collapsedDetailLabel.text = detail
        collapsedValueLabel.text = value ?? "—"
        collapsedValueLabel.textColor = tintColor
        collapsedChevronView.isHidden = !doesNavigate
        collapsedSummaryView.isHidden = false
        setNeedsLayout()
    }

    public func setExpandedAppearance() {
        collapsedSummaryView.isHidden = true
        chartContentView.isHidden = false
        titleLabel?.isHidden = false
        subtitleLabel?.isHidden = false
        rightArrowHint?.isHidden = !doesNavigate
        setNeedsLayout()
    }
    
    public func removeSubtitleLabelText() {
        subtitleLabel?.attributedText = nil
        subtitleLabel?.text?.removeAll()
    }
    
    public func setTitleTextColor(color: UIColor) {
        if let current = titleLabel?.attributedText {
            let mutable = NSMutableAttributedString(attributedString: current)
            mutable.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: mutable.length))
            titleLabel?.attributedText = mutable
        } else {
            titleLabel?.textColor = color
        }
    }
    
    public func setSubtitleTextColor(color: UIColor) {
        if let current = subtitleLabel?.attributedText {
            let mutable = NSMutableAttributedString(attributedString: current)
            mutable.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: mutable.length))
            subtitleLabel?.attributedText = mutable
        } else {
            subtitleLabel?.textColor = color
        }
    }
    
    public func setAlpha(alpha: CGFloat) {
        titleLabel?.alpha = alpha
        subtitleLabel?.alpha = alpha
        rightArrowHint?.alpha = alpha
        historyDurationSelector.alpha = alpha
    }
}

public final class HistoryDurationSelectorControl: UIControl {
    public static let availableHours: [Int] = [1, 3, 6, 12, 24]

    public var onDurationSelected: ((Int) -> Void)?

    public var selectedHours: Int = 3 {
        didSet {
            updateSelectedState()
        }
    }

    private var buttons: [Int: UIButton] = [:]
    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.spacing = 1
        return stack
    }()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        translatesAutoresizingMaskIntoConstraints = false
        layer.cornerRadius = 11
        layer.masksToBounds = true
        layer.borderWidth = 0.5

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 1.5),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1.5),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            widthAnchor.constraint(equalToConstant: 130),
            heightAnchor.constraint(equalToConstant: 22)
        ])

        for hours in Self.availableHours {
            let button = UIButton(type: .custom)
            button.setTitle("\(hours)h", for: .normal)
            button.titleLabel?.font = .dashboardRounded(ofSize: 10, weight: .semibold)
            button.layer.cornerRadius = 9.5
            button.layer.masksToBounds = true
            button.tag = hours
            button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchUpInside)
            stackView.addArrangedSubview(button)
            buttons[hours] = button
        }

        updateColors()
        updateSelectedState()
    }

    @objc private func buttonTapped(_ sender: UIButton) {
        let hours = sender.tag
        guard hours != selectedHours else { return }
        UISelectionFeedbackGenerator().selectionChanged()
        selectedHours = hours
        onDurationSelected?(hours)
    }

    public func updateColors() {
        backgroundColor = DashboardCardTheme.coral.withAlphaComponent(0.08)
        layer.borderColor = DashboardCardTheme.border.resolvedColor(with: traitCollection).cgColor

        updateSelectedState()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }

    private func updateSelectedState() {
        for (hours, button) in buttons {
            let isSelected = (hours == selectedHours)
            if isSelected {
                button.backgroundColor = DashboardCardTheme.coral
                button.setTitleColor(.white, for: .normal)
                button.titleLabel?.font = .dashboardRounded(ofSize: 10, weight: .bold)
            } else {
                button.backgroundColor = .clear
                button.setTitleColor(DashboardCardTheme.mutedInk, for: .normal)
                button.titleLabel?.font = .dashboardRounded(ofSize: 10, weight: .medium)
            }
        }
    }
}
