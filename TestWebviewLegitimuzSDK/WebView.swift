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
                
                // Save the original postMessage function
                const originalPostMessage = window.postMessage;
                
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
        
        // Enable console.log messages to show in Xcode console
        let consoleLogScript = WKUserScript(
            source: """
            var originalConsoleLog = console.log;
            console.log = function() {
                var message = Array.from(arguments).map(function(arg) {
                    if (typeof arg === 'object') {
                        try {
                            return JSON.stringify(arg);
                        } catch (e) {
                            return String(arg);
                        }
                    } else {
                        return String(arg);
                    }
                }).join(' ');
                
                // Call original console.log
                originalConsoleLog.apply(console, arguments);
                
                // Send to native
                window.webkit.messageHandlers.onSuccess.postMessage('LOG: ' + message);
            };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(consoleLogScript)

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
            
            // Inject test code to verify message handlers and test SDK event handling
            webView.evaluateJavaScript("""
                console.log('Page loaded, checking handlers');
                if (typeof window.notifySuccessToNative === 'function') {
                    console.log('Success handler is available');
                    // Simulate a Legitimuz SDK event to test the integration
                    window.postMessage({
                        name: 'test-event',
                        status: 'success',
                        refId: 'test123'
                    }, '*');
                } else {
                    console.log('WARNING: Success handler is NOT available');
                }
            """) { result, error in
                if let error = error {
                    print("Error running test script: \(error.localizedDescription)")
                } else {
                    print("Test script executed")
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
        
        // Log JavaScript console messages
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("JavaScript alert: \(message)")
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
            print("JavaScript prompt: \(prompt)")
            completionHandler("")
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            print("JavaScript confirm: \(message)")
            completionHandler(true)
        }
    }
}
