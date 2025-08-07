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
    @Published private(set) var isLoading: Bool = false
    
    // MARK: - Dependencies
    private let transactionService: TransactionServiceProtocol
    private let bitcoinRateService: BitcoinRateService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Pagination Properties
    private var currentPage = 0
    private var canLoadMore = true
    private var allTransactions: [TransactionModel] = []
    
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
        currentPage = 0
        canLoadMore = true
        allTransactions = []
        loadTransactions(page: currentPage)
        loadBalance()
    }
    
    func loadMoreTransactions() {
        guard canLoadMore, !isLoading else { return }
        currentPage += 1
        loadTransactions(page: currentPage)
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
                self?.onAppear()
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

    private func loadBalance() {
        transactionService.fetchTotalBalance()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] balance in
                self?.balanceText = "\(balance.formatted()) BTC"
            })
            .store(in: &cancellables)
    }
    
    private func loadTransactions(page: Int) {
        isLoading = true
        transactionService.fetchTransactions(page: page)
            .map { [weak self] newTransactions -> ([Date: [TransactionModel]], [Date]) in
                guard let self = self else { return ([:], []) }
                
                if newTransactions.count < 20 {
                    self.canLoadMore = false
                }
                
                self.allTransactions.append(contentsOf: newTransactions)
                
                let grouped = Dictionary(grouping: self.allTransactions) {
                    Calendar.current.startOfDay(for: $0.timestamp)
                }
                let sorted = grouped.keys.sorted(by: >)
                
                return (grouped, sorted)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            }, receiveValue: { [weak self] (grouped, sorted) in
                self?.groupedTransactions = grouped
                self?.sortedSectionDates = sorted
            })
            .store(in: &cancellables)
    }
}
