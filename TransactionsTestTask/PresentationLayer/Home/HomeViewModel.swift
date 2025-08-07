//
//  HomeViewModel.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 06.08.2025.
//

import Foundation
import Combine
import CoreData

class HomeViewModel {
    
    // MARK: - Outputs
    @Published private(set) var balanceText: String? = "Balance: 0.00 BTC"
    @Published private(set) var btcRateText: String? = "BTC/USD: Loading..."
    @Published private(set) var groupedTransactions: [Date: [TransactionModel]] = [:]
    @Published private(set) var sortedSectionDates: [Date] = []
    @Published private(set) var error: Error?
    
    // MARK: - Dependencies
    private let transactionService: TransactionServiceProtocol
    private let bitcoinRateService: BitcoinRateService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Private Properties
    private let rateDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
    
    init(transactionService: TransactionServiceProtocol, bitcoinRateService: BitcoinRateService) {
        self.transactionService = transactionService
        self.bitcoinRateService = bitcoinRateService
        
        setupBindings()
    }
    
    // MARK: - Public API
    func onAppear() {
        loadTransactions()
    }
    
    func addTransactionViewModel() -> AddTransactionViewModel {
        AddTransactionViewModel(transactionService: transactionService)
    }
    
    func addFunds(amount: Decimal) {
        transactionService.saveTransaction(input: .income(amount: amount))
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] _ in
                self?.loadTransactions()
            })
            .store(in: &cancellables)
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        bitcoinRateService.ratePublisher
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] rateData in
                guard let self = self, let rateData = rateData else { return }
                let timeString = self.rateDateFormatter.string(from: rateData.timestamp)
                self.btcRateText = String(format: "BTC/USD: %.2f at %@", rateData.rate, timeString)
            })
            .store(in: &cancellables)
    }
    
    private func loadTransactions() {
        transactionService.fetchTransactions()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] transactions in
                let balance = transactions.reduce(Decimal.zero) {
                    $0 + $1.amount
                }

                self?.updateUI(with: balance, and: transactions)
            })
            .store(in: &cancellables)
    }
    
    private func updateUI(
        with balance: Decimal,
        and transactions: [TransactionModel]
    ) {
        self.balanceText = "\(balance.formatted()) BTC"
        
        let grouped = Dictionary(grouping: transactions) { transaction -> Date in
            return Calendar.current.startOfDay(for: transaction.timestamp)
        }
        
        self.groupedTransactions = grouped
        self.sortedSectionDates = grouped.keys.sorted(by: >)
    }
}
