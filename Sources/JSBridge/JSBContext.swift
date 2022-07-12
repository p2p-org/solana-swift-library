// Copyright 2022 P2P Validator Authors. All rights reserved.
// Use of this source code is governed by a MIT-style license that can be
// found in the LICENSE file.

import Foundation
import WebKit

/// A class for managing communication between Swift and Javascript in WKWebview
public class JSBContext: NSObject {
    
    /// An id that indicates current unused local variable.
    ///
    /// The local variable will be used for temporary or permanent js data storage.
    internal var variableId: Int = 0
    
    /// A dispatch table for callback from async js functions.
    internal var promiseDispatchTable: PromiseDispatchTable = .init()

    internal let wkWebView: WKWebView

    /// A local variable prefix.
    private static let kJsbValueName = "__localBridgeVariable"
    
    /// A WKWebview channel for returning values from JS `Promise`.
    internal static let kPromiseCallback = "promiseCallback"

    public init(wkWebView: WKWebView? = nil) {
        self.wkWebView = wkWebView ?? WKWebView()

        super.init()

        let contentController = self.wkWebView.configuration.userContentController
        contentController.add(self, name: JSBContext.kPromiseCallback)
    }

    /// Get current unused local variable.
    func getNewValueId() -> String {
        defer { variableId += 1 }
        return "\(JSBContext.kJsbValueName)\(variableId)"
    }

    /// Evaluate raw js script.
    @MainActor func evaluate(_ script: String) async throws {
        let _: Any? = try await withCheckedThrowingContinuation { continuation in
            wkWebView.evaluateJavaScript(script) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    /// Evaluate raw js script that can return value.
    @MainActor func evaluate<T>(_ script: String) async throws -> T? {
        try await withCheckedThrowingContinuation { continuation in
            wkWebView.evaluateJavaScript(script) { result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: result as? T)
            }
        }
    }

    /// JS global context
    public private(set) lazy var this: JSBValue = .init(in: self, name: "this")
}

extension JSBContext: WKScriptMessageHandler {
    public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let message = message.body as? [String: AnyObject] else { return }
        guard let id = message["id"] as? Int else { return }

        if let error = message["error"] {
            //  Throw error to caller
            Task { await promiseDispatchTable.resolveWithError(for: Int64(id), error: JSBError.jsError(error)) }
        }
        Task { await promiseDispatchTable.resolve(for: Int64(id)) }
    }
}
