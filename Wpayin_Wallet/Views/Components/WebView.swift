//
//  WebView.swift
//  Wpayin_Wallet
//
//  UIKit WebView wrapper for SwiftUI
//

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var onNavigationFinished: ((URL?) -> Void)?
    
    init(
        url: URL,
        isLoading: Binding<Bool> = .constant(false),
        onNavigationFinished: ((URL?) -> Void)? = nil
    ) {
        self.url = url
        self._isLoading = isLoading
        self.onNavigationFinished = onNavigationFinished
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = UIColor.systemBackground
        webView.isOpaque = true
        webView.scrollView.backgroundColor = UIColor.systemBackground
        
        // Add debug
        print("🌐 WebView created for URL: \(url.absoluteString)")
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load if URL changed or webView is empty
        if webView.url != url {
            let request = URLRequest(url: url)
            print("🔄 WebView loading: \(url.absoluteString)")
            webView.load(request)
        } else {
            print("⏭️ WebView - same URL, skipping reload")
        }
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        
        init(_ parent: WebView) {
            self.parent = parent
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            print("🚀 WebView navigation started")
            parent.isLoading = true
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView navigation finished: \(webView.url?.absoluteString ?? "unknown")")
            parent.isLoading = false
            parent.onNavigationFinished?(webView.url)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView navigation failed: \(error.localizedDescription)")
            parent.isLoading = false
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
            parent.isLoading = false
        }
    }
}
