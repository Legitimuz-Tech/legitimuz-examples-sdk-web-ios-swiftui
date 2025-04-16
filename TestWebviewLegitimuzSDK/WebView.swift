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
        // Handle Legitimuz events with complete data
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
    var onLog: ((String, WebViewScriptMessageHandler.LogType) -> Void)?

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
        
        // Inject JavaScript code that will facilitate communication with Legitimuz SDK
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
            messageHandler.onLogCallback = parent.onLog
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
        
        // Handle JavaScript errors
        func webView(_ webView: WKWebView, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            completionHandler(.performDefaultHandling, nil)
        }
        
        // Handle JS dialogs to capture alerts
        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            print("JS Alert: \(message)")
            messageHandler.onLogCallback?(message, .info)
            completionHandler()
        }
        
        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            print("JS Confirm: \(message)")
            messageHandler.onLogCallback?(message, .info)
            completionHandler(true)
        }
    }
}
