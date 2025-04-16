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
        
        // Handle direct success/error calls
        if message.name == "onSuccess" {
            // Extract event name from different formats
            if let eventName = message.body as? String {
                if !eventName.hasPrefix("LOG:") { // Filter out console.log redirects
                    print("SDK Success (string): \(eventName)")
                    onSuccessCallback?(eventName)
                }
            } else if let dict = message.body as? [String: Any], let eventName = dict["event"] as? String {
                print("SDK Success (dict): \(eventName)")
                onSuccessCallback?(eventName)
            }
        } else if message.name == "onError" {
            // Extract event name from different formats
            if let eventName = message.body as? String {
                print("SDK Error (string): \(eventName)")
                onErrorCallback?(eventName)
            } else if let dict = message.body as? [String: Any], let eventName = dict["event"] as? String {
                print("SDK Error (dict): \(eventName)")
                onErrorCallback?(eventName)
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
            // Create event listener for Legitimuz SDK messages
            window.addEventListener('message', function(event) {
                const eventData = event.data;
                
                // Check if this looks like a Legitimuz SDK event (has name and status)
                if (eventData && typeof eventData === 'object' && eventData.name) {
                    console.log('Detected Legitimuz event:', eventData.name, 'Status:', eventData.status);
                    
                    // Forward to native code
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.legitimuzEvent) {
                        window.webkit.messageHandlers.legitimuzEvent.postMessage(eventData);
                    }
                }
            });
            
            // Define global utility functions
            window.notifySuccessToNative = function(eventName) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onSuccess) {
                    window.webkit.messageHandlers.onSuccess.postMessage(eventName);
                }
            };
            
            window.notifyErrorToNative = function(eventName) {
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.onError) {
                    window.webkit.messageHandlers.onError.postMessage(eventName);
                }
            };
            """,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(script)

        // Create the WebView with our configuration
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

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Nothing to update
    }

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

        // Grant camera permissions automatically
        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
        
        // Log page loading events
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("WebView finished loading: \(webView.url?.absoluteString ?? "")")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
        
        // Handle JavaScript dialogs
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("JavaScript alert: \(message)")
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            print("JavaScript confirm: \(message)")
            completionHandler(true)
        }
    }
}
