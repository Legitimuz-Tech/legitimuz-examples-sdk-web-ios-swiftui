# TestWebviewLegitimuzSDK

A tutorial iOS project demonstrating how to integrate the Legitimuz SDK into a WebView-based application.

## Overview

This project showcases a simple implementation of an iOS app that loads the Legitimuz SDK through a WebView. It handles the necessary permissions and configurations required for features like camera access, microphone access, and location services.

## Used for this example:

- Xcode 14.0+
- iOS 16.0+
- Swift 5.0+

## Integration Guide

Follow these steps to integrate the Legitimuz SDK using WebView:

### 1. Setup Project Permissions

For the Legitimuz SDK to function properly in a WebView, your Info.plist must include these specific permission descriptions:

```xml
<!-- Camera Permission - Required for liveness/Document -->
<key>NSCameraUsageDescription</key>
<string>This app needs access to your camera for WebView content</string>

<!-- Microphone Permission - May be required for certain SDK features -->
<key>NSMicrophoneUsageDescription</key>
<string>This app needs access to your microphone for WebView content</string>

<!-- Location Permissions - Required if using geolocation features -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>This app needs your location for WebView geolocation features</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>This app may need location access in background for WebView</string>
```

Additionally, if you need to handle URLs that might open from the WebView:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <!-- Configure URL schemes if needed -->
    </dict>
</array>
```

### 2. Create WebView Component with Legitimuz SDK Event Handling

Create a custom WebView component to properly handle permissions and events from the Legitimuz SDK:

```swift
import SwiftUI
import WebKit
import CoreLocation

// Define a message handler for JavaScript communication
class WebViewScriptMessageHandler: NSObject, WKScriptMessageHandler {
    // Create callback closures for different event types
    var onSuccessCallback: ((String) -> Void)?
    var onErrorCallback: ((String) -> Void)?
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        // Log all received messages for debugging
        print("Received message from JS: \(message.name) with body: \(message.body)")
        
        if message.name == "onSuccess" {
            // Handle string or dictionary
            if let eventName = message.body as? String {
                print("SDK Success (string): \(eventName)")
                onSuccessCallback?(eventName)
            } else if let dict = message.body as? [String: Any], let eventName = dict["event"] as? String {
                print("SDK Success (dict): \(eventName)")
                onSuccessCallback?(eventName)
            } else {
                print("SDK Success with unexpected format: \(message.body)")
            }
        } else if message.name == "onError" {
            // Handle string or dictionary
            if let eventName = message.body as? String {
                print("SDK Error (string): \(eventName)")
                onErrorCallback?(eventName)
            } else if let dict = message.body as? [String: Any], let eventName = dict["event"] as? String {
                print("SDK Error (dict): \(eventName)")
                onErrorCallback?(eventName)
            } else {
                print("SDK Error with unexpected format: \(message.body)")
            }
        } else if message.name == "legitimuzEvent" {
            // Handle Legitimuz SDK event format
            if let dict = message.body as? [String: Any], 
               let name = dict["name"] as? String, 
               let status = dict["status"] as? String {
                print("Legitimuz Event: \(name) - Status: \(status)")
                
                if status == "success" {
                    onSuccessCallback?(name)
                } else if status == "error" {
                    onErrorCallback?(name)
                }
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    // Optional callbacks to handle events from JavaScript
    var onSuccess: ((String) -> Void)?
    var onError: ((String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [] // autoplay works
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.preferences.javaScriptEnabled = true

        // Setup JavaScript message handlers
        let contentController = WKUserContentController()
        contentController.add(context.coordinator.messageHandler, name: "onSuccess")
        contentController.add(context.coordinator.messageHandler, name: "onError")
        contentController.add(context.coordinator.messageHandler, name: "legitimuzEvent")
        configuration.userContentController = contentController
        
        // Inject JavaScript code that will facilitate communication
        let script = WKUserScript(
            source: """
            // Log when script is injected
            console.log('Injecting native message handlers');
            
            // Define global functions for direct calls
            window.notifySuccessToNative = function(eventName) {
                console.log('Calling success handler with: ' + eventName);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onSuccess) {
                    window.webkit.messageHandlers.onSuccess.postMessage(eventName);
                } else {
                    console.log('onSuccess handler not available');
                }
            };
            
            window.notifyErrorToNative = function(eventName) {
                console.log('Calling error handler with: ' + eventName);
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onError) {
                    window.webkit.messageHandlers.onError.postMessage(eventName);
                } else {
                    console.log('onError handler not available');
                }
            };
            
            // Intercept Legitimuz SDK postMessage events
            (function() {
                console.log('Setting up postMessage interceptor');
                
                // Create an event listener for messages
                window.addEventListener('message', function(event) {
                    console.log('Message received:', JSON.stringify(event.data));
                    
                    try {
                        const eventData = event.data;
                        
                        // Check if this looks like a Legitimuz SDK event
                        if (eventData && typeof eventData === 'object' && eventData.name) {
                            console.log('Detected Legitimuz event:', eventData.name, 'Status:', eventData.status);
                            
                            // Forward to native code
                            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.legitimuzEvent) {
                                window.webkit.messageHandlers.legitimuzEvent.postMessage(eventData);
                            }
                            
                            // Also handle with direct callbacks for compatibility
                            if (eventData.status === 'success') {
                                window.notifySuccessToNative(eventData.name);
                            } else if (eventData.status === 'error') {
                                window.notifyErrorToNative(eventData.name);
                            }
                        }
                    } catch (err) {
                        console.error('Error processing message:', err);
                    }
                });
                
                // Log that handlers are ready
                console.log('Native message handlers and postMessage interceptor are ready');
            })();
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        // Enable debugging
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, CLLocationManagerDelegate {
        let parent: WebView
        let messageHandler = WebViewScriptMessageHandler()
        let locationManager = CLLocationManager()

        init(_ parent: WebView) {
            self.parent = parent
            super.init()
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
            
            // Set up callbacks
            messageHandler.onSuccessCallback = parent.onSuccess
            messageHandler.onErrorCallback = parent.onError
        }

        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
        
        // Add navigation delegate methods to log page loading events
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading: \(webView.url?.absoluteString ?? "")")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
    }
}
```

### 3. Implement ContentView with Event Handlers

Create a ContentView that will embed the WebView component and handle events from the Legitimuz SDK:

```swift
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
                url: URL(string: "https://demo.legitimuz.com/liveness/")!,
                // For testing KYC use: https://demo.legitimuz.com/teste-kyc/
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
```

### 4. Setup App Entry Point

Make sure your SwiftUI app's entry point loads the ContentView:

```swift
import SwiftUI

@main
struct TestWebviewLegitimuzSDKApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 5. Understanding Legitimuz SDK Event Handling

The Legitimuz SDK sends events using the `window.postMessage` API. These events have a specific format:

```javascript
{
    name: "event-name",         // e.g., "ocr", "facematch", "close-modal"
    status: "success" | "error", // Result status
    refId: "reference-id"       // Optional reference ID
}
```

Our WebView implementation intercepts these events by:

1. Setting up a message event listener in JavaScript
2. Capturing events that match the Legitimuz SDK format
3. Forwarding them to native Swift code via message handlers
4. Processing them in the `WebViewScriptMessageHandler` class

This approach ensures that:
- The native app can respond to all SDK events
- The user interface can be updated based on event status
- Debugging information is available in the console

## What Happens If You Forget Important Configurations

If you miss certain configurations or permissions, you'll encounter specific issues:

### Missing Camera Permissions in Info.plist
- **Symptom**: The app crashes when trying to access the camera, or camera access silently fails
- **User Experience**: Liveness detection cannot proceed, and the user may see a black screen or error message
- **Error**: Console may show "This app has crashed because it attempted to access privacy-sensitive data without a usage description"

### Missing WebView Camera Permission Handling
- **Symptom**: Camera access prompt appears but never completes, or permission is automatically denied
- **User Experience**: Camera doesn't activate even after granting system permissions
- **Fix**: Ensure you implement the `webView(_:requestMediaCapturePermissionFor:initiatedByFrame:type:decisionHandler:)` method in your Coordinator class

### Incorrect Media Playback Configuration
- **Symptom**: Video streaming doesn't start automatically or isn't displayed inline
- **User Experience**: Broken UI where video elements don't work as expected
- **Fix**: Make sure you've set `configuration.allowsInlineMediaPlayback = true` and `configuration.mediaTypesRequiringUserActionForPlayback = []`

### Missing Location Permissions
- **Symptom**: Location features fail silently or with errors
- **User Experience**: Any SDK features requiring location won't function
- **Fix**: Add the appropriate location permission strings to Info.plist and implement the CLLocationManagerDelegate

### Not Setting `.edgesIgnoringSafeArea(.all)`
- **Symptom**: Camera view appears with margins or is incorrectly positioned
- **User Experience**: Camera frame doesn't utilize the full screen
- **Fix**: Add the `.edgesIgnoringSafeArea(.all)` modifier to your WebView in ContentView

### Missing JavaScript Bridge Implementation
- **Symptom**: Native app doesn't receive events from the web SDK
- **User Experience**: The app appears to work but doesn't respond to SDK events
- **Fix**: Implement the message event listener and the WKScriptMessageHandler for "legitimuzEvent"

## Testing Your Integration

1. Build and run the app on a physical device (simulator has limited camera capabilities)
2. Accept the permission prompts when requested
3. Verify that the Legitimuz SDK loads properly in the WebView
4. Test the camera functionality to ensure it works as expected
5. Monitor Xcode console for SDK events to confirm proper communication

## Customization Options

You can customize the WebView implementation based on your needs:

- **URL Configuration**: Change the URL in ContentView to point to your specific Legitimuz SDK instance
- **Media Settings**: Adjust WebView media playback settings in the configuration
- **Permissions Handling**: Customize how permissions are requested and handled
- **UI Integration**: Modify how the WebView is presented in your app's UI
- **Event Handling**: Add custom logic to respond to specific SDK events

## Troubleshooting

If you encounter issues:

- **Permission Problems**: Ensure all required permission strings are in Info.plist
- **Camera Access**: Verify the app has been granted camera permissions during runtime
- **WebView Configuration**: Check that the WebView is properly configured for media capture
- **URL Loading**: Confirm the Legitimuz SDK URL is accessible and correct
- **Event Not Received**: Check the JavaScript console for errors and verify the event listener is working

## Support

For questions about the Legitimuz SDK, please contact Legitimuz support.

## TODO:
- Add how to handle events from javascript.