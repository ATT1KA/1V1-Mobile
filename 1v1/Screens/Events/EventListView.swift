import SwiftUI

struct EventListView: View {
    @StateObject private var eventService = EventService.shared
    @State private var now: Date = Date()
    
    var body: some View {
        NavigationView {
            List {
                if eventService.isLoading {
                    ProgressView()
                }
                
                if !activeEvents.isEmpty {
                    Section("Active") {
                        ForEach(activeEvents, id: \.id) { event in
                            NavigationLink(destination: EventCheckInView(event: event)) {
                                EventRow(event: event)
                            }
                        }
                    }
                }
                
                if !upcomingEvents.isEmpty {
                    Section("Upcoming") {
                        ForEach(upcomingEvents, id: \.id) { event in
                            NavigationLink(destination: EventCheckInView(event: event)) {
                                EventRow(event: event)
                            }
                        }
                    }
                }
                
                if !pastEvents.isEmpty {
                    Section("Past") {
                        ForEach(pastEvents, id: \.id) { event in
                            EventRow(event: event)
                        }
                    }
                }
            }
            .navigationTitle("Events")
            .refreshable { await eventService.fetchEvents() }
            .task { await eventService.fetchEvents() }
            .overlay(alignment: .bottom) {
                if let error = eventService.errorMessage, !error.isEmpty {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.bottom, 8)
                }
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            now = Date()
        }
    }
    
    private var activeEvents: [Event] {
        eventService.events.filter { $0.isActive }
    }
    private var upcomingEvents: [Event] {
        eventService.events.filter { $0.startTime > now }
    }
    private var pastEvents: [Event] {
        eventService.events.filter { $0.endTime < now }
    }
}

private struct EventRow: View {
    let event: Event
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.name)
                .font(.headline)
            if let venue = event.venue, !venue.isEmpty {
                Text(venue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                Text(dateRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let max = event.maxAttendees {
                    Text("Cap: \(max)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var dateRange: String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return "\(df.string(from: event.startTime)) - \(df.string(from: event.endTime))"
    }
}


