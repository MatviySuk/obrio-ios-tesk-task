//
//  MockDataGenerator.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 07.08.2025.
//


import Foundation
import Combine

enum MockDataGenerator {
    
    private static let hasGeneratedMockDataKey = "hasGeneratedMockData"
    private static var cancellable: AnyCancellable?
    
    static func run(using transactionService: TransactionServiceProtocol) {
        
        guard !UserDefaults.standard.bool(forKey: hasGeneratedMockDataKey) else {
            print("ℹ️ Mock data has already been generated. Skipping.")
            return
        }
        
        print("⏳ Generating mock transaction data...")
        
        self.cancellable = generateSampleTransactions(using: transactionService)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("❌ Failed to generate mock data: \(error.localizedDescription)")
                } else {
                    UserDefaults.standard.set(true, forKey: hasGeneratedMockDataKey)
                    print("✅ Successfully generated and saved mock data.")
                }
            }, receiveValue: { _ in })
    }
    
    private static func generateSampleTransactions(using transactionService: TransactionServiceProtocol) -> AnyPublisher<Void, Error> {
        
        var publishers: [AnyPublisher<Void, Error>] = []
        
        for _ in 0..<100 {
            let input = createRandomTransactionInput()
            let randomDate = Date.randomWithinLastWeek()
            publishers.append(transactionService.saveTransaction(input: input, timestamp: randomDate))
        }
        
        return Publishers.MergeMany(publishers)
            .collect()
            .map { _ in () }
            .eraseToAnyPublisher()
    }
    
    private static func createRandomTransactionInput() -> InputTransaction {
        let isIncome = Bool.random()
        
        if isIncome {
            let amount = Decimal.random(in: 1...1000)
            return .income(amount: amount)
        } else {
            let amount = -Decimal.random(in: 1...200)
            let category = TransactionCategory.allCases.randomElement() ?? .other
            return .expense(amount: amount, category: category)
        }
    }
}

extension Decimal {
    static func random(in range: ClosedRange<Int>) -> Decimal {
        return Decimal(Double.random(in: Double(range.lowerBound)...Double(range.upperBound)))
    }
}

extension Date {
    static func randomWithinLastWeek() -> Date {
        let calendar = Calendar.current
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date())!
        let timeInterval = Date().timeIntervalSince(sevenDaysAgo)
        let randomTimeInterval = TimeInterval.random(in: 0...timeInterval)
        return sevenDaysAgo.addingTimeInterval(randomTimeInterval)
    }
}
