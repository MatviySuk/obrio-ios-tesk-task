//
//  AddTransactionViewController.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 07.08.2025.
//

import UIKit
import Combine

class AddTransactionViewController: UIViewController {

    // MARK: - Properties
    private let viewModel: AddTransactionViewModel
    private var cancellables = Set<AnyCancellable>()
    private let categories = TransactionCategory.allCases

    // MARK: - UI Elements
    private let scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let amountContainerView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 16
        return view
    }()

    private let amountTextField: UITextField = {
        let textField = UITextField()
        textField.placeholder = "0.00"
        textField.font = .preferredFont(forTextStyle: .largeTitle)
        textField.adjustsFontForContentSizeCategory = true
        textField.keyboardType = .decimalPad
        textField.textAlignment = .center
        return textField
    }()
    
    private let categoryTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .headline)
        label.textColor = .secondaryLabel
        label.text = "Category"
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let categoryPickerView: UIPickerView = {
        let pickerView = UIPickerView()
        return pickerView
    }()
    
    private let addButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Add Expense"
        config.baseBackgroundColor = .systemRed
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        return button
    }()

    // MARK: - Initializer
    init(viewModel: AddTransactionViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "New Expense"
        
        setupUI()
        setupBindings()
        setupActions()
        setupKeyboardObservers()
        
        categoryPickerView.dataSource = self
        categoryPickerView.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        amountTextField.becomeFirstResponder()
    }

    // MARK: - Setup
    private func setupUI() {
        amountContainerView.addSubview(amountTextField)
        amountTextField.translatesAutoresizingMaskIntoConstraints = false
        
        let categoryStack = UIStackView(arrangedSubviews: [categoryTitleLabel, categoryPickerView])
        categoryStack.axis = .vertical
        categoryStack.spacing = 8
        
        let mainStack = UIStackView(arrangedSubviews: [amountContainerView, categoryStack, addButton])
        mainStack.translatesAutoresizingMaskIntoConstraints = false
        mainStack.axis = .vertical
        mainStack.spacing = 32
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(mainStack)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            amountTextField.topAnchor.constraint(equalTo: amountContainerView.topAnchor, constant: 20),
            amountTextField.leadingAnchor.constraint(equalTo: amountContainerView.leadingAnchor, constant: 20),
            amountTextField.trailingAnchor.constraint(equalTo: amountContainerView.trailingAnchor, constant: -20),
            amountTextField.bottomAnchor.constraint(equalTo: amountContainerView.bottomAnchor, constant: -20),
            
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            addButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        ])
    }
    
    private func setupBindings() {
        amountTextField.textPublisher
            .assign(to: &viewModel.$amountString)

        viewModel.isAddButtonEnabled
            .receive(on: RunLoop.main)
            .assign(to: \.isEnabled, on: addButton)
            .store(in: &cancellables)
            
        viewModel.dismissViewPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.navigationController?.popViewController(animated: true)
            }
            .store(in: &cancellables)
            
        viewModel.errorPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                self?.showErrorAlert(error)
            }
            .store(in: &cancellables)
    }
    
    private func setupActions() {
        addButton.addTarget(self, action: #selector(didTapAdd), for: .touchUpInside)
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tapGesture)
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    @objc private func keyboardWillShow(notification: NSNotification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        
        let contentInsets = UIEdgeInsets(top: 0, left: 0, bottom: keyboardFrame.height, right: 0)
        scrollView.contentInset = contentInsets
        scrollView.scrollIndicatorInsets = contentInsets
    }
    
    @objc private func keyboardWillHide(notification: NSNotification) {
        scrollView.contentInset = .zero
        scrollView.scrollIndicatorInsets = .zero
    }
    
    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: - Actions
    @objc private func didTapAdd() {
        viewModel.addTransaction()
    }
    
    private func showErrorAlert(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UIPickerView DataSource & Delegate
extension AddTransactionViewController: UIPickerViewDataSource, UIPickerViewDelegate {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return categories.count
    }
    
    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        var label: UILabel
        if let view = view as? UILabel {
            label = view
        } else {
            label = UILabel()
        }
        
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.text = categories[row].displayName
        
        return label
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        viewModel.selectedCategory = categories[row]
    }
}


// MARK: - Combine Helpers for UIControls
extension UITextField {
    var textPublisher: AnyPublisher<String?, Never> {
        NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification, object: self)
            .map { ($0.object as? UITextField)?.text }
            .eraseToAnyPublisher()
    }
}
