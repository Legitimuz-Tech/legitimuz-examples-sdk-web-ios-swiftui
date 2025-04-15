//
//  ContentView.swift
//  TestWebviewLegitimuzSDK
//
//  Created by Christian Santos on 4/15/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
            WebView(url: URL(string: "https://demo.legitimuz.com/liveness/")!)
                .edgesIgnoringSafeArea(.all)
        }

}

#Preview {
    ContentView()
}
