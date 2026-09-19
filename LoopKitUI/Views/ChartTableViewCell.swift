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

    private var currentDotColor: UIColor?

    public private(set) lazy var dotIndicatorView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.layer.cornerRadius = 4
        view.layer.masksToBounds = true
        view.isHidden = true
        return view
    }()

    public override func awakeFromNib() {
        super.awakeFromNib()
        setupCardAppearance()
        setupDotIndicator()
    }

    public override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCardAppearance()
        setupDotIndicator()
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
        if let color = currentDotColor {
            dotIndicatorView.backgroundColor = color
        }
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

    private func setupDotIndicator() {
        guard let titleLabel = titleLabel, dotIndicatorView.superview == nil else { return }

        contentView.addSubview(dotIndicatorView)

        for constraint in contentView.constraints {
            if (constraint.firstItem as? UIView) == titleLabel && constraint.firstAttribute == .leading {
                constraint.isActive = false
            }
        }

        NSLayoutConstraint.activate([
            dotIndicatorView.widthAnchor.constraint(equalToConstant: 8),
            dotIndicatorView.heightAnchor.constraint(equalToConstant: 8),
            dotIndicatorView.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            dotIndicatorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 14),
            titleLabel.leadingAnchor.constraint(equalTo: dotIndicatorView.trailingAnchor, constant: 8)
        ])
    }

    public func setDotColor(_ color: UIColor?) {
        self.currentDotColor = color
        if let color = color {
            dotIndicatorView.backgroundColor = color
            dotIndicatorView.isHidden = false
        } else {
            dotIndicatorView.isHidden = true
        }
    }
    
    public override func prepareForReuse() {
        super.prepareForReuse()
        doesNavigate = true
        chartContentView.chartGenerator = nil
        dotIndicatorView.isHidden = true
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
        dotIndicatorView.alpha = alpha
    }
}
