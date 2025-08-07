//
//  TransactionCell.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 06.08.2025.
//

import UIKit

class TransactionCell: UITableViewCell {
    
    // MARK: - Static Properties
    static let identifier = "TransactionCell"
    
    // MARK: - UI Elements
    private let amountLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let categoryLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .secondaryLabel
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let timeLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.textColor = .tertiaryLabel
        label.textAlignment = .right
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    // MARK: - Initializer
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        let verticalStackView = UIStackView(arrangedSubviews: [amountLabel, categoryLabel])
        verticalStackView.axis = .vertical
        verticalStackView.spacing = 4
        
        contentView.addSubview(verticalStackView)
        contentView.addSubview(timeLabel)
        
        verticalStackView.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            verticalStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            verticalStackView.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),
            verticalStackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            verticalStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Configuration
    public func configure(with transaction: TransactionModel) {
        let amount = transaction.amount.formatted()
        amountLabel.text = "\(amount) BTC"
        
        switch transaction.type {
        case .income:
            amountLabel.textColor = .systemGreen
            categoryLabel.text = "Deposit"
        case .expense(let category):
            amountLabel.textColor = .systemRed
            categoryLabel.text = category.displayName
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        timeLabel.text = dateFormatter.string(from: transaction.timestamp)
    }
}
