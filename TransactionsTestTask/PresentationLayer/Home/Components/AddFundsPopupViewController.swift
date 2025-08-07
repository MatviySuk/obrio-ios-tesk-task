//
//  AddFundsPopupViewController.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 07.08.2025.
//

import UIKit
import Combine

class AddFundsPopupViewController: UIViewController {

    // MARK: - Properties
    var onAddPublisher: AnyPublisher<Decimal, Never> {
        onAddSubject.eraseToAnyPublisher()
    }
    private let onAddSubject = PassthroughSubject<Decimal, Never>()

    // MARK: - UI Elements
    private let popupContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .systemBackground
        view.layer.cornerRadius = 16
        view.layer.masksToBounds = true
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.text = "Add Funds"
        label.textAlignment = .center
        return label
    }()
    
    private let amountTextField: UITextField = {
        let textField = UITextField()
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.placeholder = "0.00"
        textField.font = .systemFont(ofSize: 22)
        textField.keyboardType = .decimalPad
        textField.borderStyle = .roundedRect
        textField.textAlignment = .center
        return textField
    }()
    
    private let addButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Add"
        config.baseBackgroundColor = .systemGreen
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private let cancelButton: UIButton = {
        var config = UIButton.Configuration.gray()
        config.title = "Cancel"
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        setupUI()
        setupActions()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        amountTextField.becomeFirstResponder()
    }

    // MARK: - Setup
    private func setupUI() {
        let buttonStackView = UIStackView(arrangedSubviews: [cancelButton, addButton])
        buttonStackView.axis = .horizontal
        buttonStackView.spacing = 12
        buttonStackView.distribution = .fillEqually
        
        let mainStackView = UIStackView(arrangedSubviews: [titleLabel, amountTextField, buttonStackView])
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        mainStackView.axis = .vertical
        mainStackView.spacing = 20
        
        view.addSubview(popupContainerView)
        popupContainerView.addSubview(mainStackView)
        
        NSLayoutConstraint.activate([
            popupContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            popupContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            popupContainerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8),
            
            mainStackView.topAnchor.constraint(equalTo: popupContainerView.topAnchor, constant: 20),
            mainStackView.leadingAnchor.constraint(equalTo: popupContainerView.leadingAnchor, constant: 20),
            mainStackView.trailingAnchor.constraint(equalTo: popupContainerView.trailingAnchor, constant: -20),
            mainStackView.bottomAnchor.constraint(equalTo: popupContainerView.bottomAnchor, constant: -20),
            
            addButton.heightAnchor.constraint(equalToConstant: 44),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private func setupActions() {
        addButton.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)
        cancelButton.addTarget(self, action: #selector(didTapCancel), for: .touchUpInside)
    }
    
    // MARK: - Actions
    @objc private func didTapAdd() {
        guard let amountText = amountTextField.text, !amountText.isEmpty else { return }
        
        let sanitizedString = amountText.replacingOccurrences(of: ",", with: ".")
        
        if let amount = Decimal(string: sanitizedString) {
            onAddSubject.send(amount)
        }
        
        dismiss(animated: true)
    }
    
    @objc private func didTapCancel() {
        dismiss(animated: true)
    }
}
