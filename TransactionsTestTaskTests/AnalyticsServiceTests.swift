//
//  AnalyticsServiceTests.swift
//  TransactionsTestTask
//
//  Created by Matviy Suk on 07.08.2025.
//


import XCTest
@testable import TransactionsTestTask

final class AnalyticsServiceTests: XCTestCase {

    var sut: AnalyticsService!

    override func setUp() {
        super.setUp()
        sut = AnalyticsServiceImpl()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testTrackEvent_AddsEventCorrectly() async {
        let eventName: EventName = .transactionAdded
        let parameters = ["amount": "100"]
        
        await sut.trackEvent(eventName, parameters: parameters)
        
        let events = await sut.getEvents(named: nil, in: nil)
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.name, eventName.stringValue)
        XCTAssertEqual(events.first?.parameters, parameters)
    }
    
    func testTrackEvent_IsThreadSafe() async {
        let expectation = XCTestExpectation(description: "All events are tracked concurrently without crashing.")
        let dispatchGroup = DispatchGroup()
        let eventCount = 100
        
        for i in 0..<eventCount {
            dispatchGroup.enter()
            DispatchQueue.global().async {
                Task {
                    await self.sut.trackEvent(.custom("event_\(i)"), parameters: [:])
                    dispatchGroup.leave()
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            Task {
                let events = await self.sut.getEvents(named: nil, in: nil)
                XCTAssertEqual(events.count, eventCount)
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }

    func testGetEvents_WhenNoFilters_ReturnsAllEvents() async {
        await sut.trackEvent(.bitcoinRateUpdate, parameters: [:])
        await sut.trackEvent(.transactionAdded, parameters: [:])
        
        let events = await sut.getEvents(named: nil, in: nil)
        
        XCTAssertEqual(events.count, 2)
    }

    func testGetEvents_WithNameFilter_ReturnsMatchingEvents() async {
        await sut.trackEvent(.bitcoinRateUpdate, parameters: [:])
        await sut.trackEvent(.transactionAdded, parameters: [:])
        
        let events = await sut.getEvents(named: [.bitcoinRateUpdate], in: nil)
        
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.name, EventName.bitcoinRateUpdate.stringValue)
    }

    func testGetEvents_WithDateRangeFilter_ReturnsMatchingEvents() async {
        await sut.trackEvent(.custom("event1"), parameters: [:])
        try? await Task.sleep(nanoseconds: 10_000_000)
        let searchStartDate = Date()
        try? await Task.sleep(nanoseconds: 10_000_000)
        await sut.trackEvent(.custom("event2"), parameters: [:])
        try? await Task.sleep(nanoseconds: 10_000_000)
        let searchEndDate = Date()
        try? await Task.sleep(nanoseconds: 10_000_000)
        await sut.trackEvent(.custom("event3"), parameters: [:])
        
        let dateRange = DateInterval(start: searchStartDate, end: searchEndDate)
        
        let events = await sut.getEvents(named: nil, in: dateRange)
        
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.name, "event2")
    }
    
    func testGetEvents_WithAllFilters_ReturnsMatchingEvents() async {
        await sut.trackEvent(.bitcoinRateUpdate, parameters: [:])
        try? await Task.sleep(nanoseconds: 10_000_000)
        let searchStartDate = Date()
        try? await Task.sleep(nanoseconds: 10_000_000)
        await sut.trackEvent(.transactionAdded, parameters: [:])
        try? await Task.sleep(nanoseconds: 10_000_000)
        let searchEndDate = Date()
        try? await Task.sleep(nanoseconds: 10_000_000)
        await sut.trackEvent(.transactionAdded, parameters: [:])
        
        let dateRange = DateInterval(start: searchStartDate, end: searchEndDate)
        
        let events = await sut.getEvents(named: [.transactionAdded], in: dateRange)
        
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.name, EventName.transactionAdded.stringValue)
    }
    
    func testGetEvents_WithEmptyNameSet_ReturnsAllEvents() async {
        await sut.trackEvent(.bitcoinRateUpdate, parameters: [:])
        await sut.trackEvent(.transactionAdded, parameters: [:])
        
        let events = await sut.getEvents(named: [], in: nil)
        
        XCTAssertEqual(events.count, 2)
    }
}
