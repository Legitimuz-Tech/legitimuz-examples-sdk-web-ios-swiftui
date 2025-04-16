# TestWebviewLegitimuzSDK

A tutorial iOS project demonstrating how to integrate the Legitimuz SDK into a WebView-based application.

## Overview

This project showcases a simple implementation of an iOS app that loads the Legitimuz SDK through a WebView. It handles the necessary permissions and configurations required for features like camera access, microphone access, and location services. The app also implements JavaScript console logging for debugging purposes.

## Features

- WebView integration with the Legitimuz SDK
- Event handling for SDK events (`success`, `error`, etc.)
- Camera and microphone permission handling
- Status bar displaying current SDK status
- JavaScript console logging (logs are printed to Xcode console)
- Handling of uncaught JavaScript errors and unhandled promise rejections

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

### 2. Create WebView Component with Legitimuz SDK Event Handling and Console Logging

Create a custom WebView component to properly handle permissions, console logs, and events from the Legitimuz SDK:

```swift
import SwiftUI
import WebKit
import CoreLocation

// Define a message handler for JavaScript communication
class WebViewScriptMessageHandler: NSObject, WKScriptMessageHandler {
    // Create callback closures for different event types
    var onSuccessCallback: ((String) -> Void)?
    var onErrorCallback: ((String) -> Void)?
    var onEventCallback: (([String: Any]) -> Void)?
    var onLogCallback: ((String, LogType) -> Void)?
    
    // Log types for different console messages
    enum LogType {
        case log
        case error
        case warning
        case info
        case debug
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("Received message from JS: \(message.name) with body: \(message.body)")
        
        // Handle console logs
        if message.name == "consoleLog", let body = message.body as? [String: Any],
           let type = body["type"] as? String,
           let content = body["content"] as? String {
            
            let logType: LogType
            switch type {
            case "error": logType = .error
            case "warn": logType = .warning
            case "info": logType = .info
            case "debug": logType = .debug
            default: logType = .log
            }
            
            print("JS \(type): \(content)")
            onLogCallback?(content, logType)
        }
        // Handle Legitimuz events
        else if message.name == "legitimuzEvent", let dict = message.body as? [String: Any] {
            print("Legitimuz Event: \(dict)")
            onEventCallback?(dict)
            
            // Also forward to success/error for backward compatibility
            if let name = dict["name"] as? String {
                let status = dict["status"] as? String ?? "unknown"
                
                if status == "success" {
                    onSuccessCallback?(name)
                } else if status == "error" {
                    onErrorCallback?(name)
                }
            }
        }
        // Handle direct success/error calls
        else if message.name == "onSuccess" {
            if let eventName = message.body as? String {
                print("SDK Success: \(eventName)")
                onSuccessCallback?(eventName)
            }
        }
        else if message.name == "onError" {
            if let eventName = message.body as? String {
                print("SDK Error: \(eventName)")
                onErrorCallback?(eventName)
            }
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL
    var onSuccess: ((String) -> Void)?
    var onError: ((String) -> Void)?
    var onEvent: (([String: Any]) -> Void)?
    var onLog: ((String, WebViewScriptMessageHandler.LogType) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.preferences.javaScriptEnabled = true

        // Setup JavaScript message handlers
        let contentController = WKUserContentController()
        contentController.add(context.coordinator.messageHandler, name: "onSuccess")
        contentController.add(context.coordinator.messageHandler, name: "onError")
        contentController.add(context.coordinator.messageHandler, name: "legitimuzEvent")
        contentController.add(context.coordinator.messageHandler, name: "consoleLog")
        configuration.userContentController = contentController
        
        // Inject JavaScript code for console logging
        let consoleScript = WKUserScript(
            source: """
            (function() {
                function captureLog(type, originalFunc) {
                    return function() {
                        // Call the original console function
                        originalFunc.apply(console, arguments);
                        
                        // Convert all arguments to strings
                        const args = Array.from(arguments).map(arg => {
                            if (typeof arg === 'object') {
                                try {
                                    return JSON.stringify(arg);
                                } catch (e) {
                                    return String(arg);
                                }
                            }
                            return String(arg);
                        });
                        
                        // Send to native code
                        window.webkit.messageHandlers.consoleLog.postMessage({
                            type: type,
                            content: args.join(' ')
                        });
                    };
                }
                
                // Capture all console methods
                console.log = captureLog('log', console.log);
                console.error = captureLog('error', console.error);
                console.warn = captureLog('warn', console.warn);
                console.info = captureLog('info', console.info);
                console.debug = captureLog('debug', console.debug);
                
                // Also capture uncaught errors
                window.addEventListener('error', function(event) {
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'error',
                        content: 'UNCAUGHT ERROR: ' + event.message + ' at ' + event.filename + ':' + event.lineno
                    });
                });
                
                // Capture promise rejections
                window.addEventListener('unhandledrejection', function(event) {
                    let reason = event.reason ? event.reason.message || String(event.reason) : 'Unknown Promise Error';
                    window.webkit.messageHandlers.consoleLog.postMessage({
                        type: 'error',
                        content: 'UNHANDLED PROMISE: ' + reason
                    });
                });
            })();
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(consoleScript)
        
        // Inject JavaScript code for event handling
        let script = WKUserScript(
            source: """
            // Listen for Legitimuz events via postMessage
            window.addEventListener('message', function(event) {
                if (event.data && typeof event.data === 'object' && event.data.name) {
                    window.webkit.messageHandlers.legitimuzEvent.postMessage(event.data);
                }
            });
            
            // Simple success/error helpers
            window.notifySuccessToNative = function(eventName) {
                window.webkit.messageHandlers.onSuccess.postMessage(eventName);
            };
            
            window.notifyErrorToNative = function(eventName) {
                window.webkit.messageHandlers.onError.postMessage(eventName);
            };
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)

        // Create and configure WebView
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator
        
        // Enable debugging on supported iOS versions
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }

        // Load the URL
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
            messageHandler.onEventCallback = parent.onEvent
            messageHandler.onLogCallback = parent.onLog
        }

        // Handle camera permissions
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            print("Camera permission granted")
            decisionHandler(.grant)
        }
        
        // Navigation delegate methods
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView loaded: \(webView.url?.absoluteString ?? "")")
            messageHandler.onSuccessCallback?("page_loaded")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
            messageHandler.onErrorCallback?("navigation_failed")
        }
        
        // Handle JavaScript alerts
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("JS Alert: \(message)")
            messageHandler.onLogCallback?(message, .info)
            completionHandler()
        }
    }
}
```

### 3. Implement ContentView

Create a ContentView that will embed the WebView component, handle events, and show status:

```swift
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
            
            // Status bar display (can be hidden by the user)
            if showStatusBar {
                VStack {
                    StatusBar(
                        sdkStatus: sdkStatus,
                        eventData: lastEvent,
                        onDismiss: {
                            withAnimation { showStatusBar = false }
                        }
                    )
                    Spacer()
                }
                .transition(.move(edge: .top))
                .allowsHitTesting(false) // Let touches pass through to the WebView
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

## How JavaScript Console Logging Works

This implementation captures all JavaScript console output and forwards it to the native app:

1. **Console Method Interception**: All `console.log`, `console.error`, `console.warn`, `console.info`, and `console.debug` calls are intercepted
2. **Error Event Capture**: Uncaught JavaScript errors and unhandled promise rejections are also captured
3. **Native Forwarding**: All console output is sent to the native app via `webkit.messageHandlers.consoleLog`
4. **Log Processing**: The `WebViewScriptMessageHandler` converts these messages to native log entries
5. **Xcode Console Output**: All logs are printed to the Xcode console with their type

This provides several benefits:
- Full visibility into JavaScript execution
- Capture of errors that might otherwise be invisible
- Ability to correlate JavaScript issues with SDK behavior
- Enhanced debugging capabilities for web content

### Example Log Format

Logs appear in the Xcode console with this format:

```
[log] This is a regular console.log message
[error] This is a console.error message
[warning] This is a console.warn message
[info] This is a console.info message
[debug] This is a console.debug message
[error] UNCAUGHT ERROR: ReferenceError: undefinedVariable is not defined at https://example.com:123
```

## Understanding SDK Event Handling

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
- **No Console Logs**: Ensure the console logging script is injected at document start and the message handler is registered

## Support

For questions about the Legitimuz SDK, please contact Legitimuz support.