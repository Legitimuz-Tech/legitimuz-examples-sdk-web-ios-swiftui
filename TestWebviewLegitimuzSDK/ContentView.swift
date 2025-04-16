//
//  ContentView.swift
//  TestWebviewLegitimuzSDK
//
//  Created by Christian Santos on 4/15/25.
//

import SwiftUI

/// Main view container for the Legitimuz SDK test application
/// Displays a WebView with JavaScript communication capabilities and a status bar
struct ContentView: View {
    /// Current status message to display in the status bar
    @State private var sdkStatus: String = "Ready"
    /// Controls visibility of the status bar overlay
    @State private var showStatusBar: Bool = true
    /// Stores the most recent event data received from the WebView
    @State private var lastEvent: [String: Any] = [:]
    
    var body: some View {
        ZStack(alignment: .top) {
            // WebView - loads the Legitimuz demo and handles all communication
            WebView(
                url: URL(string: "https://demo.legitimuz.com/teste-kyc/")!,
                onSuccess: { event in
                    print("Success: \(event)")
                    sdkStatus = "Success: \(event)"
                },
                onError: { event in
                    print("Error: \(event)")
                    sdkStatus = "Error: \(event)"
                },
                onEvent: { eventData in
                    // Save and display the event data
                    lastEvent = eventData
                    if let name = eventData["name"] as? String {
                        let status = eventData["status"] as? String ?? "unknown"
                        sdkStatus = "\(name) (\(status))"
                    }
                },
                onLog: { message, logType in
                    // Log JavaScript console messages to Xcode console
                    print("[\(logType)] \(message)")
                    
                    // If it's an error, update the visible status
                    if logType == .error {
                        sdkStatus = "Error: \(message.prefix(30))..."
                    }
                }
            )
            .edgesIgnoringSafeArea(.all)
            
            // Status overlay - displays current SDK status and latest event
            if showStatusBar {
                VStack {
                    StatusBar(
                        sdkStatus: sdkStatus,
                        eventData: lastEvent,
                        onDismiss: {
                            withAnimation { showStatusBar = false }
                        }
                    )
                    Spacer() // Push the status bar to the top
                }
                .transition(.move(edge: .top))
                .allowsHitTesting(false) // Critical: Let touches pass through to the WebView
            }
            
            // Floating button to show status when hidden
            if !showStatusBar {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation { showStatusBar = true }
                        }) {
                            Image(systemName: "info.circle.fill")
                                .font(.title)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Circle().fill(Color.blue.opacity(0.8)))
                                .shadow(radius: 3)
                        }
                        .padding()
                    }
                    Spacer()
                }
            }
        }
    }
}

/// Status bar component that displays the current SDK status and event information
struct StatusBar: View {
    /// Current status message to display
    let sdkStatus: String
    /// Event data from the most recent event
    let eventData: [String: Any]
    /// Callback when the user dismisses the status bar
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            // Status display section
            VStack(alignment: .leading, spacing: 4) {
                Text("SDK Status: \(sdkStatus)")
                    .font(.headline)
                
                if let name = eventData["name"] as? String {
                    Text("Event: \(name)")
                        .font(.caption)
                    
                    if let refId = eventData["refId"] as? String, !refId.isEmpty {
                        Text("RefID: \(refId)")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            Spacer()
            
            // Dismiss button - explicitly made interactive
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(12)
                    .background(Circle().fill(Color.white.opacity(0.8)))
                    .shadow(radius: 2)
            }
            .allowsHitTesting(true)
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

#Preview {
    ContentView()
}
