//
//  MockBitcoinRateCacheService.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 07.08.2025.
//


import XCTest
import Combine
@testable import TransactionsTestTask 

// MARK: - Mocks

class MockBitcoinRateCacheService: BitcoinRateCacheService {
    private var cachedRate: BitcoinUSDRate?

    func getBitcoinUSDRate() -> BitcoinUSDRate? {
        return cachedRate
    }

    func cache(rate: BitcoinUSDRate) {
        self.cachedRate = rate
    }
}

class MockBitcoinRateFetcher: BitcoinRateFetching {
    var result: Result<Double, Error> = .failure(URLError(.notConnectedToInternet))

    func fetchRate() async throws -> Double {
        switch result {
        case .success(let rate):
            return rate
        case .failure(let error):
            throw error
        }
    }
}

// MARK: - UserDefaultsRateCacheTests

final class UserDefaultsRateCacheTests: XCTestCase {
    
    var sut: UserDefaultsRateCache!
    let testKey = "BitcoinRateCacheKey"

    override func setUp() {
        super.setUp()
        sut = UserDefaultsRateCache()
        UserDefaults.standard.removeObject(forKey: testKey)
    }

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: testKey)
        sut = nil
        super.tearDown()
    }

    func testCache_SavesRateToUserDefaults() {
        let rate = BitcoinUSDRate(rate: 50000.0, timestamp: Date())
        
        sut.cache(rate: rate)
        
        let retrieved = sut.getBitcoinUSDRate()
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.rate, rate.rate)
    }

    func testGetBitcoinUSDRate_WhenNoCache_ReturnsNil() {
        let retrieved = sut.getBitcoinUSDRate()
        
        XCTAssertNil(retrieved)
    }
}

// MARK: - BitcoinRateServiceImplTests

final class BitcoinRateServiceImplTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!
    var mockCacheService: MockBitcoinRateCacheService!
    var mockFetcher: MockBitcoinRateFetcher!
    var sut: BitcoinRateServiceImpl!

    override func setUp() {
        super.setUp()
        cancellables = []
        mockCacheService = MockBitcoinRateCacheService()
        mockFetcher = MockBitcoinRateFetcher()
    }

    override func tearDown() {
        sut?.stop()
        sut = nil
        cancellables = nil
        mockCacheService = nil
        mockFetcher = nil
        super.tearDown()
    }

    func testInit_WhenCacheExists_PublishesCachedRate() {
        let cachedRate = BitcoinUSDRate(rate: 50000.0, timestamp: Date())
        mockCacheService.cache(rate: cachedRate)
        let expectation = XCTestExpectation(description: "Publishes the initial cached rate.")
        
        sut = BitcoinRateServiceImpl(cacheService: mockCacheService, fetchInterval: 1000, fetcher: mockFetcher)
        
        var receivedRate: BitcoinUSDRate?
        sut.ratePublisher
            .sink { rate in
                receivedRate = rate
                if rate?.rate == cachedRate.rate {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedRate?.rate, cachedRate.rate)
    }
    
    func testFetchRate_WhenSuccessful_CachesAndPublishesNewRate() async {
        let newRateValue = 60000.0
        mockFetcher.result = .success(newRateValue)
        
        sut = BitcoinRateServiceImpl(cacheService: mockCacheService, fetchInterval: 0.1, fetcher: mockFetcher)
        let expectation = XCTestExpectation(description: "Fetches, caches, and publishes a new rate.")
        
        sut.ratePublisher
            .dropFirst()
            .sink { rate in
                if rate?.rate == newRateValue {
                    XCTAssertEqual(self.mockCacheService.getBitcoinUSDRate()?.rate, newRateValue)
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        sut.start()
            
        await fulfillment(of: [expectation], timeout: 1.0)
    }
    
    func testFetchRate_WhenFails_HoldsLastKnownValue() async {
        let initialCachedRate = BitcoinUSDRate(rate: 50000.0, timestamp: Date())
        mockCacheService.cache(rate: initialCachedRate)
        mockFetcher.result = .failure(URLError(.notConnectedToInternet))
        
        sut = BitcoinRateServiceImpl(cacheService: mockCacheService, fetchInterval: 0.1, fetcher: mockFetcher)
        
        var receivedValue: BitcoinUSDRate?
        sut.ratePublisher
            .sink { value in
                receivedValue = value
            }
            .store(in: &cancellables)
            
        sut.start()
            
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertEqual(receivedValue?.rate, initialCachedRate.rate)
    }
}
