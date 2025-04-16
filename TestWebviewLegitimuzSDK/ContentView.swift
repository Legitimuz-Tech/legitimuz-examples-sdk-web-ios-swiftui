//
//  ContentView.swift
//  TestWebviewLegitimuzSDK
//
//  Created by Christian Santos on 4/15/25.
//

import SwiftUI

struct ContentView: View {
    @State private var sdkStatus: String = "Ready"
    @State private var showStatusBar: Bool = true
    @State private var lastEvent: [String: Any] = [:]
    
    var body: some View {
        ZStack(alignment: .top) {
            // WebView - this needs to receive touch events even when status bar is showing
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
                    // Just print to console, no UI display
                    print("[\(logType)] \(message)")
                    
                    // If it's an error, update status
                    if logType == .error {
                        sdkStatus = "Error: \(message.prefix(30))..."
                    }
                }
            )
            .edgesIgnoringSafeArea(.all)
            
            // Status overlay - modified to not block touches
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

// Extracted status bar for cleaner code
struct StatusBar: View {
    let sdkStatus: String
    let eventData: [String: Any]
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(alignment: .top) {
            // Non-interactive status display
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
            
            // Just the button needs to be touchable
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(12)
                    .background(Circle().fill(Color.white.opacity(0.8)))
                    .shadow(radius: 2)
            }
            .allowsHitTesting(true) // Explicitly allow button interaction
        }
        .padding(.horizontal)
        .padding(.top, 10)
    }
}

#Preview {
    ContentView()
}
