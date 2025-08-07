//
//  BitcoinRateService.swift
//  TransactionsTestTask
//
//

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

// MARK: - Fetching Service Protocol
protocol BitcoinRateFetching {
    func fetchRate() async throws -> Double
}

class LiveBitcoinRateFetcher: BitcoinRateFetching {
    private let urlSession: URLSession
    private let decoder = JSONDecoder()
    /// In production level software URL mustn't be forced. Instead it has to be parsed fron config and safely unwrapped.
    private let url = URL(string: "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd")!

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func fetchRate() async throws -> Double {
        let (data, _) = try await urlSession.data(from: url)
        let decodedData = try decoder.decode([String: PriceData].self, from: data)
        guard let rate = decodedData["bitcoin"]?.usd else {
            throw URLError(.cannotParseResponse)
        }
        return rate
    }
}


// MARK: - Bitcoin Rate Service Protocol
protocol BitcoinRateService: AnyObject {
    var ratePublisher: AnyPublisher<BitcoinUSDRate?, Never> { get }
    func start()
    func stop()
}

// MARK: - Implementation
final class BitcoinRateServiceImpl: BitcoinRateService {
    
    var ratePublisher: AnyPublisher<BitcoinUSDRate?, Never> {
        rateSubject.eraseToAnyPublisher()
    }
    
    private let cacheService: BitcoinRateCacheService
    private let fetcher: BitcoinRateFetching
    private let fetchInterval: TimeInterval
    
    private let rateSubject: CurrentValueSubject<BitcoinUSDRate?, Never>
    private var fetchTask: Task<Void, Never>?

    init(
        cacheService: BitcoinRateCacheService = UserDefaultsRateCache(),
        fetchInterval: TimeInterval = 5.0,
        fetcher: BitcoinRateFetching = LiveBitcoinRateFetcher()
    ) {
        self.cacheService = cacheService
        self.fetchInterval = fetchInterval
        self.fetcher = fetcher
        
        self.rateSubject = CurrentValueSubject(cacheService.getBitcoinUSDRate())
    }
    
    deinit {
        stop()
    }
    
    func start() {
        guard fetchTask == nil else { return }
        
        fetchTask = Task {
            while !Task.isCancelled {
                await fetchRate()
                try? await Task.sleep(nanoseconds: UInt64(fetchInterval * 1_000_000_000))
            }
        }
    }
    
    func stop() {
        fetchTask?.cancel()
        fetchTask = nil
    }
    
    private func fetchRate() async {
        do {
            let rate = try await fetcher.fetchRate()
            handleSuccessfulFetch(rate: rate)
        } catch {
            handleFailedFetch(error: error)
        }
    }
    
    private func handleSuccessfulFetch(rate: Double) {
        let newRate = BitcoinUSDRate(rate: rate, timestamp: .now)
        cacheService.cache(rate: newRate)
        rateSubject.send(newRate)
    }
    
    private func handleFailedFetch(error: Error) {
        print("Bitcoin rate fetch failed: \(error.localizedDescription). Holding last known value.")
    }
}

// MARK: - Codable Structs for API Response
private struct PriceData: Codable {
    let usd: Double
}
