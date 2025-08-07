//
//  TransactionService.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 06.08.2025.
//

import Foundation
import Combine
import CoreData

// MARK: - Transaction Service Protocol
public protocol TransactionServiceProtocol {
    func fetchTransactions() -> AnyPublisher<[TransactionModel], Error>
    func saveTransaction(input: InputTransaction) -> AnyPublisher<Void, Error>
}

// MARK: - Concrete Transaction Service
public class TransactionService: TransactionServiceProtocol {
    private let context: NSManagedObjectContext
    
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    public func fetchTransactions() -> AnyPublisher<[TransactionModel], Error> {
        return Future<[TransactionModel], Error> { promise in
            self.context.perform {
                let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
                let sortByDate = NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)
                fetchRequest.sortDescriptors = [sortByDate]
                
                do {
                    // TODO: add logging of transaction records that failed to mapping to model.
                    // In normal conditions this shouldn't happen as Transaction consistency is
                    // validated before commiting it.
                    let transactions = try self.context.fetch(fetchRequest).compactMap {
                        let model = $0.toModel()
                        
                        if model == nil {
                            print("Error: failed to parse model.")
                        }

                        return model
                    }
                    promise(.success(transactions))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func saveTransaction(input: InputTransaction) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            self.context.perform {
                let newTransaction = Transaction(context: self.context)
                newTransaction.id = UUID()
                newTransaction.timestamp = Date()
                
                switch input {
                case .income(let amount):
                    newTransaction.amount = amount as NSDecimalNumber
                case .expense(let amount, let category):
                    newTransaction.amount = amount as NSDecimalNumber
                    newTransaction.categoryRawValue = category.rawValue as NSNumber
                }
                
                do {
                    try self.context.save()
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}
