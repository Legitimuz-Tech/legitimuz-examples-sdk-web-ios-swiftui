import SwiftUI
import WebKit
import CoreLocation

// Define a message handler for JavaScript communication
class WebViewScriptMessageHandler: NSObject, WKScriptMessageHandler {
    // Create callback closures for different event types
    var onSuccessCallback: ((String) -> Void)?
    var onErrorCallback: ((String) -> Void)?
    var onEventCallback: (([String: Any]) -> Void)?
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("Received message from JS: \(message.name) with body: \(message.body)")
        
        // Handle Legitimuz events with complete data
        if message.name == "legitimuzEvent", let dict = message.body as? [String: Any] {
            print("Legitimuz Event: \(dict)")
            onEventCallback?(dict)
            
            // Also forward to success/error for backward compatibility
            if let name = dict["name"] as? String {
                let status = dict["status"] as? String ?? "unknown"
                
                if status == "success" {
                    onSuccessCallback?(name)
                } else if status == "error" {
                    onErrorCallback?(name)
                } else if !name.contains("error") && !name.contains("fail") {
                    onSuccessCallback?(name)
                } else {
                    onErrorCallback?(name)
                }
            }
        }
        // Direct success/error calls
        else if message.name == "onSuccess" {
            if let eventName = message.body as? String {
                print("SDK Success: \(eventName)")
                onSuccessCallback?(eventName)
            } else if let dict = message.body as? [String: Any], let eventName = dict["event"] as? String {
                print("SDK Success: \(eventName)")
                onSuccessCallback?(eventName)
            }
        }
        else if message.name == "onError" {
            if let eventName = message.body as? String {
                print("SDK Error: \(eventName)")
                onErrorCallback?(eventName)
            } else if let dict = message.body as? [String: Any], let eventName = dict["event"] as? String {
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
        }

        // Grant camera permissions automatically
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
    }
}
