# TestWebviewLegitimuzSDK

A tutorial iOS project demonstrating how to integrate the Legitimuz SDK into a WebView-based application.

## Overview

This project showcases a simple implementation of an iOS app that loads the Legitimuz SDK through a WebView. It handles the necessary permissions and configurations required for features like camera access, microphone access, and location services.

## Requirements

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

### 2. Create WebView Component

Create a custom WebView component to properly handle permissions and configure settings needed by the Legitimuz SDK:

```swift
import SwiftUI
import WebKit
import CoreLocation

struct WebView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = [] // autoplay works
        configuration.allowsPictureInPictureMediaPlayback = false

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = context.coordinator
        webView.navigationDelegate = context.coordinator

        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKUIDelegate, WKNavigationDelegate, CLLocationManagerDelegate {
        let locationManager = CLLocationManager()

        override init() {
            super.init()
            locationManager.delegate = self
            locationManager.requestWhenInUseAuthorization()
        }

        func webView(_ webView: WKWebView,
                     requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                     initiatedByFrame frame: WKFrameInfo,
                     type: WKMediaCaptureType,
                     decisionHandler: @escaping (WKPermissionDecision) -> Void) {
            decisionHandler(.grant)
        }
    }
}
```

Key configurations:
- Enables inline media playback
- Allows autoplay of media content
- Sets up delegates for handling camera and location permissions
- Automatically grants media capture permissions

### 3. Implement ContentView

Create a ContentView that will embed the WebView component and load the Legitimuz SDK URL:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        // Create a WebView that loads the Legitimuz SDK URL
        WebView(url: URL(string: "https://demo.legitimuz.com/liveness/")!)
            // Make the WebView take up the entire screen, including areas normally reserved for system UI
            //For testing KYC use: https://demo.legitimuz.com/teste-kyc/
            .edgesIgnoringSafeArea(.all)
    }
}

// Preview provider for SwiftUI canvas
#Preview {
    ContentView()
}
```

The `.edgesIgnoringSafeArea(.all)` modifier ensures that the WebView fills the entire screen, which is important for the Legitimuz SDK to function properly with camera views and other full-screen features.

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

## Testing Your Integration

1. Build and run the app on a physical device (simulator has limited camera capabilities)
2. Accept the permission prompts when requested
3. Verify that the Legitimuz SDK loads properly in the WebView
4. Test the camera functionality to ensure it works as expected

## Customization Options

You can customize the WebView implementation based on your needs:

- **URL Configuration**: Change the URL in ContentView to point to your specific Legitimuz SDK instance
- **Media Settings**: Adjust WebView media playback settings in the configuration
- **Permissions Handling**: Customize how permissions are requested and handled
- **UI Integration**: Modify how the WebView is presented in your app's UI

## Troubleshooting

If you encounter issues:

- **Permission Problems**: Ensure all required permission strings are in Info.plist
- **Camera Access**: Verify the app has been granted camera permissions during runtime
- **WebView Configuration**: Check that the WebView is properly configured for media capture
- **URL Loading**: Confirm the Legitimuz SDK URL is accessible and correct

## Support

For questions about the Legitimuz SDK, please contact Legitimuz support.

