//
//  ChartTableViewCell.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 2/19/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


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
        }
    }


    public private(set) lazy var historyDurationSelector: HistoryDurationSelectorControl = {
        let selector = HistoryDurationSelectorControl()
        selector.isHidden = true
        return selector
    }()

    private var historyDurationSelectorConstraints: [NSLayoutConstraint] = []

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
        rightArrowHint?.tintColor = .tertiaryLabel
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
        let isDark = traitCollection.userInterfaceStyle == .dark
        contentView.backgroundColor = isDark
            ? UIColor(red: 22/255, green: 22/255, blue: 25/255, alpha: 0.95)
            : UIColor.secondarySystemGroupedBackground
        contentView.layer.borderColor = isDark
            ? UIColor.white.withAlphaComponent(0.08).cgColor
            : UIColor(red: 226/255, green: 232/255, blue: 240/255, alpha: 1.0).cgColor
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        let horizontalMargin: CGFloat = 14
        let verticalMargin: CGFloat = 5
        contentView.frame = bounds.inset(by: UIEdgeInsets(top: verticalMargin, left: horizontalMargin, bottom: verticalMargin, right: horizontalMargin))
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
        doesNavigate = true
        chartContentView.chartGenerator = nil
        hideHistoryDurationSelector()
        titleLabel?.attributedText = nil
        titleLabel?.text = nil
        subtitleLabel?.attributedText = nil
        subtitleLabel?.text = nil
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
            .font: UIFont.systemFont(ofSize: 12, weight: .bold),
            .kern: 1.2,
            .foregroundColor: UIColor.secondaryLabel
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
            .font: UIFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold),
            .foregroundColor: UIColor.secondaryLabel
        ]
        subtitleLabel?.attributedText = NSAttributedString(string: label, attributes: attributes)
    }

    public func setAttributedSubtitleLabel(_ attributedString: NSAttributedString?) {
        subtitleLabel?.attributedText = attributedString
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
            button.titleLabel?.font = .systemFont(ofSize: 10, weight: .semibold)
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
        let isDark = traitCollection.userInterfaceStyle == .dark
        backgroundColor = isDark
            ? UIColor(white: 1.0, alpha: 0.08)
            : UIColor(white: 0.0, alpha: 0.06)
        layer.borderColor = isDark
            ? UIColor(white: 1.0, alpha: 0.12).cgColor
            : UIColor(white: 0.0, alpha: 0.08).cgColor

        updateSelectedState()
    }

    public override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateColors()
    }

    private func updateSelectedState() {
        let isDark = traitCollection.userInterfaceStyle == .dark
        for (hours, button) in buttons {
            let isSelected = (hours == selectedHours)
            if isSelected {
                button.backgroundColor = isDark
                    ? UIColor(white: 0.32, alpha: 1.0)
                    : UIColor.white
                button.setTitleColor(isDark ? .white : .black, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 10, weight: .bold)
            } else {
                button.backgroundColor = .clear
                button.setTitleColor(.secondaryLabel, for: .normal)
                button.titleLabel?.font = .systemFont(ofSize: 10, weight: .medium)
            }
        }
    }
}
