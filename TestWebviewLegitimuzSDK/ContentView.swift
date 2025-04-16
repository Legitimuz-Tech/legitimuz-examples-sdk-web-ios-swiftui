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
            // WebView
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
                }
            )
            .edgesIgnoringSafeArea(.all)
            
            // Status overlay
            if showStatusBar {
                StatusView(
                    sdkStatus: sdkStatus,
                    eventData: lastEvent,
                    onDismiss: {
                        withAnimation { showStatusBar = false }
                    }
                )
                .transition(.move(edge: .top))
            }
        }
    }
}

// Extracted status view for cleaner code
struct StatusView: View {
    let sdkStatus: String
    let eventData: [String: Any]
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack {
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
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle")
                        .padding()
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            
            Spacer()
        }
        .background(Color.black.opacity(0.01)) // Invisible touch area
    }
}

#Preview {
    ContentView()
}
