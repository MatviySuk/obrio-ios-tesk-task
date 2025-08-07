//
//  CoreDataService.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 06.08.2025.
//

import CoreData

protocol CoreDataService {
    /// A service dedicated to managing Transaction entities.
    var transactionService: TransactionServiceProtocol { get }
}

// MARK: - Core Data Service Implementation
final class CoreDataServiceImpl: CoreDataService {

    // MARK: - Properties
    let transactionService: TransactionServiceProtocol

    private let persistentContainer: NSPersistentContainer

    // MARK: - Initializer
    init() {
        persistentContainer = NSPersistentContainer(name: "TransactionsTestTask")
        
        persistentContainer.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        
        self.transactionService = TransactionService(context: persistentContainer.viewContext)
    }
}
