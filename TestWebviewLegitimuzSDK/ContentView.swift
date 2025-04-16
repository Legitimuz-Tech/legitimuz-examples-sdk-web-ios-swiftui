//
//  ContentView.swift
//  TestWebviewLegitimuzSDK
//
//  Created by Christian Santos on 4/15/25.
//

import SwiftUI

struct ContentView: View {
    @State private var sdkStatus: String = "Ready"
    
    var body: some View {
        VStack {
            // Status indicator to show SDK events
            Text("SDK Status: \(sdkStatus)")
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.top, 10)
            
            // WebView with event handlers
            WebView(
                url: URL(string: "https://2drsc405k4gb.share.zrok.io/70b1f614-f9c3-46d8-950b-d7407ecd828f/?lang=pt")!,
                onSuccess: { event in
                    // Handle success events from the SDK
                    print("Success event received: \(event)")
                    sdkStatus = "Success: \(event)"
                },
                onError: { event in
                    // Handle error events from the SDK
                    print("Error event received: \(event)")
                    sdkStatus = "Error: \(event)"
                }
            )
            .edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview {
    ContentView()
}
