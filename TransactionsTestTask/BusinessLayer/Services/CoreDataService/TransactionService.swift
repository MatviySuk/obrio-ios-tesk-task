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
    func fetchTransactions(page: Int) -> AnyPublisher<[TransactionModel], Error>
    func fetchTotalBalance() -> AnyPublisher<Decimal, Error>
    func saveTransaction(input: InputTransaction) -> AnyPublisher<Void, Error>
    func saveTransaction(input: InputTransaction, timestamp: Date) -> AnyPublisher<Void, Error>
}

public extension TransactionServiceProtocol {
    func saveTransaction(input: InputTransaction) -> AnyPublisher<Void, Error> {
        return saveTransaction(input: input, timestamp: Date())
    }
}

// MARK: - Concrete Transaction Service
public class TransactionService: TransactionServiceProtocol {
    private let context: NSManagedObjectContext
    private let pageSize = 20
    
    public init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    public func fetchTransactions(page: Int) -> AnyPublisher<[TransactionModel], Error> {
        return Future<[TransactionModel], Error> { promise in
            self.context.perform {
                let fetchRequest: NSFetchRequest<Transaction> = Transaction.fetchRequest()
                let sortByDate = NSSortDescriptor(keyPath: \Transaction.timestamp, ascending: false)
                fetchRequest.sortDescriptors = [sortByDate]
                
                fetchRequest.fetchLimit = self.pageSize
                fetchRequest.fetchOffset = page * self.pageSize
                
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

    public func fetchTotalBalance() -> AnyPublisher<Decimal, Error> {
        return Future<Decimal, Error> { promise in
            self.context.perform {
                let fetchRequest: NSFetchRequest<NSDictionary> = NSFetchRequest(entityName: "Transaction")
                fetchRequest.resultType = .dictionaryResultType

                let expressionDesc = NSExpressionDescription()
                expressionDesc.name = "balance"
                expressionDesc.expression = NSExpression(forFunction: "sum:", arguments: [NSExpression(forKeyPath: #keyPath(Transaction.amount))])
                expressionDesc.expressionResultType = .decimalAttributeType
                
                fetchRequest.propertiesToFetch = [expressionDesc]
                
                do {
                    let result = try self.context.fetch(fetchRequest)
                    let balance = result.first?["balance"] as? Decimal ?? Decimal.zero
                    promise(.success(balance))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func saveTransaction(input: InputTransaction, timestamp: Date) -> AnyPublisher<Void, Error> {
        return Future<Void, Error> { promise in
            self.context.perform {
                let newTransaction = Transaction(context: self.context)
                newTransaction.id = UUID()
                newTransaction.timestamp = timestamp
                
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
