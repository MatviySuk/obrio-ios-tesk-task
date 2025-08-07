//
//  AddTransactionViewModel.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 07.08.2025.
//

import Foundation
import Combine

final class AddTransactionViewModel {
    
    // MARK: - Outputs
    var isAddButtonEnabled: AnyPublisher<Bool, Never> {
        $amountString
            .map { amountText -> Bool in
                guard let text = amountText, !text.isEmpty else { return false }
                let sanitizedText = text.replacingOccurrences(of: ",", with: ".")
                return Decimal(string: sanitizedText) != nil
            }
            .eraseToAnyPublisher()
    }
    
    let dismissViewPublisher = PassthroughSubject<Void, Never>()
    let errorPublisher = PassthroughSubject<Error, Never>()
    
    // MARK: - Properties
    @Published var amountString: String?
    @Published var selectedCategory: TransactionCategory = .groceries
    
    private let transactionService: TransactionServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initializer
    init(transactionService: TransactionServiceProtocol) {
        self.transactionService = transactionService
    }
    
    // MARK: - Public API
    func addTransaction() {
        guard let amountText = amountString else { return }
        
        let sanitizedText = amountText.replacingOccurrences(of: ",", with: ".")
        guard let amount = Decimal(string: sanitizedText) else { return }
        
        // Expenses are stored as negative values
        let expenseAmount = -abs(amount)
        
        transactionService
            .saveTransaction(
                input: .expense(
                    amount: expenseAmount,
                    category: selectedCategory
                )
            )
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.errorPublisher.send(error)
                }
            }, receiveValue: { [weak self] in
                self?.dismissViewPublisher.send()
            })
            .store(in: &cancellables)
    }
}
