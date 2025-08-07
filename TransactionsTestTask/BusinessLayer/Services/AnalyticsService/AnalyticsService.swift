//
//  AnalyticsService.swift
//  TransactionsTestTask
//
//

import Foundation

// MARK: - Analytics Service
public protocol AnalyticsService: AnyObject {
    func trackEvent(_ eventName: EventName, parameters: [String: String]) async
    
    func getEvents(
        named eventNames: Set<EventName>?,
        in dateRange: DateInterval?
    ) async -> [AnalyticsEvent]
}

public enum EventName: Equatable, Hashable {
    case bitcoinRateUpdate
    case bitcoinRateFetchFailed
    case transactionAdded
    case custom(String)
    
    var stringValue: String {
        switch self {
        case .bitcoinRateUpdate:
            return "bitcoin_rate_update"
        case .bitcoinRateFetchFailed:
            return "bitcoin_rate_fetch_failed"
        case .transactionAdded:
            return "transaction_added"
        case .custom(let name):
            return name
        }
    }
}

public final actor AnalyticsServiceImpl: AnalyticsService {
    
    private var events: [AnalyticsEvent] = []

    public init() {}
    
    public func trackEvent(_ eventName: EventName, parameters: [String: String]) {
        let event = AnalyticsEvent(
            name: eventName.stringValue,
            parameters: parameters,
            date: .now
        )
        
        events.append(event)
#if DEBUG
        print("Analytics: Logged event '\(event.name)' with parameters: \(event.parameters)")
#endif
    }
    
    public func getEvents(
        named eventNames: Set<EventName>?,
        in dateRange: DateInterval?
    ) -> [AnalyticsEvent] {
        var filteredEvents = self.events
        
        if let eventNames = eventNames, !eventNames.isEmpty {
            let stringEventNames = Set(eventNames.map { $0.stringValue })
            filteredEvents = filteredEvents.filter { stringEventNames.contains($0.name) }
        }
        
        if let dateRange = dateRange {
            filteredEvents = filteredEvents.filter { dateRange.contains($0.date) }
        }
        
        return filteredEvents
    }
}
