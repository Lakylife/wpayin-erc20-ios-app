//
//  PlainHTTPGuard.swift
//  Wpayin_Wallet
//
//  The app allows plain http in Info.plist (NSAllowsArbitraryLoads) only so
//  that a user-entered Quintium node can be reached before it has https.
//  This guard keeps every other request on https: an http request is refused
//  unless its host is the Quintium node, its explorer, or a host on the
//  local network.
//

import Foundation

final class PlainHTTPGuard: URLProtocol {
    private static let lock = NSLock()
    private static var extraHosts = Set<String>()

    /// Call once at launch, before the first request.
    static func install() {
        URLProtocol.registerClass(PlainHTTPGuard.self)
    }

    /// Lets a node the user is just testing (not saved yet) be reached over http.
    static func allow(host: String?) {
        guard let host = host?.lowercased(), !host.isEmpty else { return }
        lock.lock(); defer { lock.unlock() }
        extraHosts.insert(host)
    }

    /// True when the request must not leave the device: plain http to a host
    /// that is neither local nor a Quintium node the user entered.
    static func isBlocked(_ url: URL?) -> Bool {
        guard let url = url, url.scheme?.lowercased() == "http" else { return false }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return true }
        if QuintiumSettings.isLocalHost(host) { return false }
        lock.lock()
        let extra = extraHosts.contains(host)
        lock.unlock()
        if extra { return false }
        return !quintiumHosts().contains(host)
    }

    private static func quintiumHosts() -> Set<String> {
        var hosts = Set<String>()
        for network in QuintiumNetwork.allCases {
            for value in [QuintiumSettings.rpcUrl(for: network), QuintiumSettings.explorerUrl(for: network)] {
                if let host = URL(string: value)?.host?.lowercased() { hosts.insert(host) }
            }
        }
        return hosts
    }

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool {
        isBlocked(request.url)
    }

    override class func canInit(with task: URLSessionTask) -> Bool {
        isBlocked(task.currentRequest?.url ?? task.originalRequest?.url)
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.appTransportSecurityRequiresSecureConnection))
    }

    override func stopLoading() {}
}
