//
//  Transaction.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 06.08.2025.
//

import Foundation
import CoreData

@objc(Transaction)
class Transaction: NSManagedObject {
    func toModel() -> TransactionModel? {
        guard let id = self.id,
              let timestamp = self.timestamp,
              let amount = (self.amount as? Decimal),
              let type = self.type else {
            return nil
        }
        
        return TransactionModel(
            id: id,
            amount: amount,
            type: type,
            timestamp: timestamp
        )
    }
}

public struct TransactionModel {
    let id: UUID
    let amount: Decimal
    let type: TransactionType
    let timestamp: Date
}

public enum InputTransaction {
    case income(amount: Decimal)
    case expense(amount: Decimal, category: TransactionCategory)
}

// MARK: - Transaction Enums
public enum TransactionType {
    case income
    case expense(TransactionCategory)
}

public enum TransactionCategory: Int16, CaseIterable {
    case groceries = 0
    case taxi = 1
    case electronics = 2
    case restaurant = 3
    case other = 4
    
    public var displayName: String {
        switch self {
        case .groceries:
            return "Groceries"
        case .taxi:
            return "Taxi"
        case .electronics:
            return "Electronics"
        case .restaurant:
            return "Restaurant"
        case .other:
            return "Other"
        }
    }
}

// MARK: - Transaction Extension
extension Transaction {
    // MARK: - Validation Error
    public enum ValidationError: Error, LocalizedError {
        case missingCategoryForExpense
        case categoryOnIncomeTransaction
        
        public var errorDescription: String? {
            switch self {
            case .missingCategoryForExpense:
                return "An expense transaction must have a category."
            case .categoryOnIncomeTransaction:
                return "An income transaction cannot have a category."
            }
        }
    }
    
    // MARK: - Computed Properties
    public var type: TransactionType? {
        guard let amount = self.amount as? Decimal else {
            return nil
        }
        
        if amount < 0 {
            guard let categoryRawValue = self.categoryRawValue,
                  let category = TransactionCategory(rawValue: categoryRawValue.int16Value) else {
                return nil
            }
            
            return .expense(category)
        } else {
            return .income
        }
    }
    
    // MARK: - Validation Logic
    private func checkConsistency() throws {
        guard let amount = self.amount as? Decimal else {
            return
        }
        
        if amount >= 0 && categoryRawValue != nil {
            throw ValidationError.categoryOnIncomeTransaction
        }
        
        if amount < 0 && categoryRawValue == nil {
            throw ValidationError.missingCategoryForExpense
        }
    }
    
    public override func validateForInsert() throws {
        try super.validateForInsert()
        try self.checkConsistency()
    }
    
    public override func validateForUpdate() throws {
        try super.validateForUpdate()
        try self.checkConsistency()
    }
}
