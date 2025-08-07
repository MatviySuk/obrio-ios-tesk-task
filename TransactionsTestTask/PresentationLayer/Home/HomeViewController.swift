//
//  HomeViewController.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 06.08.2025.
//

import UIKit
import Combine

class HomeViewController: UIViewController {

    // MARK: - UI Elements
    private let headerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 20
        view.layer.masksToBounds = true
        return view
    }()

    private let balanceTitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textColor = .secondaryLabel
        label.text = "Current Balance"
        return label
    }()
    
    private let balanceLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 34, weight: .bold)
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.textColor = .label
        return label
    }()
    
    private let addFundsButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        button.setImage(UIImage(systemName: "plus.circle.fill", withConfiguration: config), for: .normal)
        button.tintColor = .systemGreen
        button.setContentCompressionResistancePriority(.required, for: .horizontal)
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }()
    
    private let btcRateLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .tertiaryLabel
        label.textAlignment = .left
        return label
    }()
    
    private let addTransactionButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Add Transaction"
        config.image = UIImage(systemName: "plus")
        config.imagePadding = 8
        config.baseBackgroundColor = .systemBlue
        config.cornerStyle = .medium
        let button = UIButton(configuration: config)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private let transactionsTableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .insetGrouped)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.backgroundColor = .clear
        tableView.register(TransactionCell.self, forCellReuseIdentifier: TransactionCell.identifier)
        return tableView
    }()
    
    // MARK: - Properties
    private let viewModel: HomeViewModel
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initializer
    init(viewModel: HomeViewModel) {
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
        title = "Bitcoin Wallet"
        
        setupUI()
        setupActions()
        setupBindings()
        
        transactionsTableView.dataSource = self
        transactionsTableView.delegate = self
        
        viewModel.onAppear()
    }
    
    // MARK: - Setup
    private func setupUI() {
        let balanceStackView = UIStackView(arrangedSubviews: [balanceLabel, addFundsButton])
        balanceStackView.axis = .horizontal
        balanceStackView.spacing = 12
        balanceStackView.alignment = .center

        let headerContentStackView = UIStackView(arrangedSubviews: [balanceTitleLabel, balanceStackView, btcRateLabel])
        headerContentStackView.translatesAutoresizingMaskIntoConstraints = false
        headerContentStackView.axis = .vertical
        headerContentStackView.alignment = .leading
        headerContentStackView.spacing = 4
        headerContentStackView.setCustomSpacing(12, after: balanceStackView)
        
        view.addSubview(headerView)
        headerView.addSubview(headerContentStackView)
        view.addSubview(addTransactionButton)
        view.addSubview(transactionsTableView)
        
        NSLayoutConstraint.activate([
            headerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            headerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            headerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            headerContentStackView.topAnchor.constraint(equalTo: headerView.topAnchor, constant: 20),
            headerContentStackView.leadingAnchor.constraint(equalTo: headerView.leadingAnchor, constant: 20),
            headerContentStackView.trailingAnchor.constraint(equalTo: headerView.trailingAnchor, constant: -20),
            headerContentStackView.bottomAnchor.constraint(equalTo: headerView.bottomAnchor, constant: -20),
            
            addTransactionButton.topAnchor.constraint(equalTo: headerView.bottomAnchor, constant: 24),
            addTransactionButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            addTransactionButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            addTransactionButton.heightAnchor.constraint(equalToConstant: 50),
            
            transactionsTableView.topAnchor.constraint(equalTo: addTransactionButton.bottomAnchor, constant: 8),
            transactionsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            transactionsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            transactionsTableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupActions() {
        addFundsButton.addTarget(self, action: #selector(didTapAddFunds), for: .touchUpInside)
        addTransactionButton.addTarget(self, action: #selector(didTapAddTransaction), for: .touchUpInside)
    }
    
    private func setupBindings() {
        viewModel.$balanceText
            .receive(on: RunLoop.main)
            .assign(to: \.text, on: balanceLabel)
            .store(in: &cancellables)
            
        viewModel.$btcRateText
            .receive(on: RunLoop.main)
            .assign(to: \.text, on: btcRateLabel)
            .store(in: &cancellables)
            
        viewModel.$groupedTransactions
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.transactionsTableView.reloadData()
            }
            .store(in: &cancellables)
            
        viewModel.$error
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] error in
                self?.showErrorAlert(error)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Actions & Alerts
    @objc private func didTapAddFunds() {
        let popupVC = AddFundsPopupViewController()
        popupVC.modalPresentationStyle = .overCurrentContext
        popupVC.modalTransitionStyle = .crossDissolve
        
        popupVC.onAddPublisher
            .sink { [weak self] amount in
                self?.viewModel.addFunds(amount: amount)
            }
            .store(in: &cancellables)
        
        present(popupVC, animated: true)
    }
    
    @objc private func didTapAddTransaction() {
        print("Navigate to Add Transaction Screen")
    }
    
    private func showErrorAlert(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource & Delegate
extension HomeViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int {
        return viewModel.sortedSectionDates.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let dateKey = viewModel.sortedSectionDates[section]
        return viewModel.groupedTransactions[dateKey]?.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let dateKey = viewModel.sortedSectionDates[section]
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .none
        return dateFormatter.string(from: dateKey).uppercased()
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TransactionCell.identifier, for: indexPath) as? TransactionCell else {
            return UITableViewCell()
        }
        
        let dateKey = viewModel.sortedSectionDates[indexPath.section]
        if let transaction = viewModel.groupedTransactions[dateKey]?[indexPath.row] {
            cell.configure(with: transaction)
        }
        return cell
    }
}
