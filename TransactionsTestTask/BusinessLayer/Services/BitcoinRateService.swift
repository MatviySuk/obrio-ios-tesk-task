//
//  BitcoinRateService.swift
//  TransactionsTestTask
//
//

/// Rate Service should fetch data from https://api.coindesk.com/v1/bpi/currentprice.json
/// Fetching should be scheduled with dynamic update interval
/// Rate should be cached for the offline mode
/// Every successful fetch should be logged with analytics service
/// The service should be covered by unit tests

import Foundation
import Combine

// MARK: - Caching Service
protocol BitcoinRateCacheService {
    func getBitcoinUSDRate() -> BitcoinUSDRate?
    func cache(rate: BitcoinUSDRate)
}

class UserDefaultsRateCache: BitcoinRateCacheService {
    private let cacheKey = "BitcoinRateCacheKey"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    func getBitcoinUSDRate() -> BitcoinUSDRate? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey) else { return nil }
        return try? decoder.decode(BitcoinUSDRate.self, from: data)
    }
    
    func cache(rate: BitcoinUSDRate) {
        if let data = try? encoder.encode(rate) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}


// MARK: - Bitcoin Rate Service Protocol
protocol BitcoinRateService: AnyObject {
    var ratePublisher: AnyPublisher<BitcoinUSDRate?, Error> { get }
}

// MARK: - Implementation
final class BitcoinRateServiceImpl: BitcoinRateService {
    
    // MARK: - Public Properties
    var ratePublisher: AnyPublisher<BitcoinUSDRate?, Error> {
        rateSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    private let analyticsService: AnalyticsService
    private let cacheService: BitcoinRateCacheService
    private let urlSession: URLSession
    private let decoder = JSONDecoder()
    
    // MARK: - Private Properties
    /// In production level software URL mustn't be forced. Instead it has to be parsed fron config and safely unwrapped.
    private let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd")!
    private let rateSubject: CurrentValueSubject<BitcoinUSDRate?, Error>
    private var timerCancellable: AnyCancellable?
    private var fetchCancellable: AnyCancellable?
    
    // MARK: - Init
    init(
        analyticsService: AnalyticsService,
        cacheService: BitcoinRateCacheService = UserDefaultsRateCache(),
        fetchInterval: TimeInterval = 15.0,
        urlSession: URLSession = .shared
    ) {
        self.analyticsService = analyticsService
        self.cacheService = cacheService
        self.urlSession = urlSession
        
        self.rateSubject = CurrentValueSubject(cacheService.getBitcoinUSDRate())
        
        fetchRate()
        
        timerCancellable = Timer.publish(every: fetchInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchRate()
            }
    }
    
    // MARK: - Private Fetch Logic
    private func fetchRate() {
        fetchCancellable = urlSession.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: [String: PriceData].self, decoder: decoder)
            .compactMap { $0["bitcoin"]?.usd }
            .sink(receiveCompletion: { [weak self] completion in
                if case .failure(let error) = completion {
                    self?.analyticsService.trackEvent(
                        name: "BitcoinRateFetchFailed",
                        parameters: ["error": error.localizedDescription]
                    )
                    
                    print("Fetch failed: \(error.localizedDescription). Holding last known value.")
                }
            }, receiveValue: { [weak self] rate in
                self?.handleSuccessfulFetch(rate: rate)
            })
    }
    
    private func handleSuccessfulFetch(rate: Double) {
        analyticsService.trackEvent(name: "BitcoinRateUpdate", parameters: ["rate": String(rate)])
        
        let newRate = BitcoinUSDRate(rate: rate, timestamp: .now)
        cacheService.cache(rate: newRate)
        
        rateSubject.send(newRate)
    }
}

// MARK: - Codable Structs for API Response
private struct PriceData: Codable {
    let usd: Double
}
