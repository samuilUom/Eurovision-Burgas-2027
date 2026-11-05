import SwiftUI
import WebKit

struct GoogleRestaurantReviewsView: View {
    let request: GoogleRestaurantRequest
    var embedded = false
    @State private var attempt = UUID()
    @State private var loading = true
    @State private var error: String?
    @State private var contentHeight: CGFloat = 320
    private let matches = GoogleRestaurantMatches()

    var body: some View {
        Group {
            if let base = GoogleReviewsConfiguration.widgetURL,
               let url = request.widgetURL(base: base, placeID: matches.placeID(for: request), embedded: embedded) {
                VStack(spacing: 0) {
                    if embedded {
                        HStack {
                            Label("Google Maps", systemImage: "globe").font(.headline)
                            Spacer()
                            controls
                        }.padding(.bottom, 12)
                    }
                    if loading { ProgressView("Свързване с Google…").padding() }
                    if let error {
                        ContentUnavailableView {
                            Label("Ревютата не се заредиха", systemImage: "exclamationmark.bubble")
                        } description: { Text(error) } actions: {
                            Button("Опитай пак") { retry() }.buttonStyle(.borderedProminent)
                        }
                    }
                    GoogleReviewsWebView(url: url, request: request, embedded: embedded,
                                         loading: $loading, error: $error, contentHeight: $contentHeight)
                        .id(attempt)
                        .frame(height: error != nil ? 0 : (embedded ? contentHeight : nil))
                        .frame(maxHeight: embedded ? nil : .infinity)
                        .accessibilityLabel("Google ревюта за \(request.name)")
                }
                .toolbar {
                    if !embedded { ToolbarItem(placement: .primaryAction) { controls } }
                }
            } else {
                ContentUnavailableView("Google ревюта — скоро", systemImage: "star.bubble", description:
                    Text("Свързваме ревютата от Google за това заведение. Междувременно можеш да четеш и добавяш ревюта в приложението."))
            }
        }
        .background(embedded ? Color.clear : Theme.background)
    }
    private var controls: some View {
        Menu {
            Button("Обнови", systemImage: "arrow.clockwise") { retry() }
            Button("Избери друго съвпадение", systemImage: "mappin.and.ellipse") {
                matches.remove(for: request); retry()
            }
        } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
            .accessibilityLabel("Настройки на Google ревютата")
    }
    private func retry() { error = nil; loading = true; contentHeight = 320; attempt = UUID() }
}

private struct GoogleReviewsWebView: UIViewRepresentable {
    let url: URL
    let request: GoogleRestaurantRequest
    let embedded: Bool
    @Binding var loading: Bool
    @Binding var error: String?
    @Binding var contentHeight: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.userContentController.add(context.coordinator, name: "restaurantReviews")
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.isOpaque = false
        view.backgroundColor = embedded ? .clear : .systemBackground
        view.scrollView.backgroundColor = .clear
        view.scrollView.isScrollEnabled = !embedded
        view.load(URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 25))
        return view
    }
    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        view.scrollView.isScrollEnabled = !embedded || contentHeight >= 12_000
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading(); view.navigationDelegate = nil; view.uiDelegate = nil
        view.configuration.userContentController.removeScriptMessageHandler(forName: "restaurantReviews")
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        var parent: GoogleReviewsWebView
        init(_ parent: GoogleReviewsWebView) { self.parent = parent }
        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame, let origin = message.frameInfo.request.url,
                  GoogleReviewsConfiguration.sameOrigin(origin, parent.url),
                  let body = message.body as? [String: Any] else { return }
            switch body["event"] as? String {
            case "ready": parent.loading = false
            case "match":
                if let id = body["placeID"] as? String { GoogleRestaurantMatches().save(id, for: parent.request) }
            case "clearMatch": GoogleRestaurantMatches().remove(for: parent.request)
            case "height":
                if parent.embedded, let value = body["height"] as? Double,
                   let height = GoogleReviewsConfiguration.embeddedHeight(value),
                   abs(parent.contentHeight - height) > 1 { parent.contentHeight = height }
            default: break
            }
        }
        func webView(_ view: WKWebView, didFinish navigation: WKNavigation!) { parent.loading = false }
        func webView(_ view: WKWebView, decidePolicyFor response: WKNavigationResponse,
                     decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
            if response.isForMainFrame, let http = response.response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                parent.loading = false
                parent.error = "Страницата с Google ревютата е временно недостъпна. Опитай отново след малко."
                decisionHandler(.cancel)
            } else { decisionHandler(.allow) }
        }
        func webView(_ view: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { failed(error) }
        func webView(_ view: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
        func webViewWebContentProcessDidTerminate(_ view: WKWebView) {
            parent.loading = false; parent.error = "Страницата беше затворена от телефона. Опитай отново."
        }
        private func failed(_ error: Error) {
            guard (error as NSError).code != NSURLErrorCancelled else { return }
            parent.loading = false
            parent.error = (error as NSError).code == NSURLErrorNotConnectedToInternet
                ? "Няма връзка с интернет. Провери връзката и опитай пак."
                : "Връзката с Google ревютата е временно недостъпна. Опитай отново след малко."
        }
        func webView(_ view: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard let destination = action.request.url else { decisionHandler(.cancel); return }
            if action.targetFrame?.isMainFrame == false { decisionHandler(.allow); return }
            if GoogleReviewsConfiguration.sameOrigin(destination, parent.url) { decisionHandler(.allow); return }
            // Keep the embedded view on its configured origin. Only deliberate taps open source links.
            if action.navigationType == .linkActivated, destination.scheme == "https" {
                UIApplication.shared.open(destination)
            }
            decisionHandler(.cancel)
        }
        func webView(_ view: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // decidePolicyFor handles deliberate source links, including target=_blank.
            nil
        }
    }
}
