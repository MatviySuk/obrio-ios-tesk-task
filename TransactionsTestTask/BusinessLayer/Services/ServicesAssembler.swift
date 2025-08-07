//
//  ServicesAssembler.swift
//  TransactionsTestTask
//
//

import Foundation
import Combine

final class ServicesAssembler {
    let bitcoinRateService: BitcoinRateService
    let analyticsService: AnalyticsService
    let coreDataService: CoreDataService
    
    private var cancellables = Set<AnyCancellable>()

    init() {
        self.analyticsService = AnalyticsServiceImpl()
        self.coreDataService = CoreDataServiceImpl()
        self.bitcoinRateService = BitcoinRateServiceImpl()
        
        setupBitcoinRateLogging()

        bitcoinRateService.start()
    }
    
    private func setupBitcoinRateLogging() {
        bitcoinRateService.ratePublisher
            .sink(receiveValue: { [weak self] rateData in
                guard let rateData = rateData else { return }
                
                Task {
                    await self?.analyticsService.trackEvent(
                        .bitcoinRateUpdate,
                        parameters: ["rate": String(rateData.rate)]
                    )
                }
            })
            .store(in: &cancellables)
    }
}
