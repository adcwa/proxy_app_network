import XCTest
@testable import ProxyEngine

final class ProxyEngineTests: XCTestCase {
    
    func testRuleMatchingDomain() {
        let manager = RuleManager()
        manager.add(rule: Rule(type: .domain("*.google.com"), action: .proxy(host: "127.0.0.1", port: 1080, type: .socks5)))
        
        let action1 = manager.match(appBundleId: nil, targetHost: "mail.google.com")
        if case .proxy = action1 {
            XCTAssertTrue(true)
        } else {
            XCTFail("Should match wildcard domain")
        }
        
        let action2 = manager.match(appBundleId: nil, targetHost: "baidu.com")
        if case .direct = action2 {
            XCTAssertTrue(true)
        } else {
            XCTFail("Should fall back to direct")
        }
    }
    
    func testRuleMatchingApp() {
        let manager = RuleManager()
        manager.add(rule: Rule(type: .app("Safari"), action: .proxy(host: "127.0.0.1", port: 1080, type: .socks5)))
        
        let action1 = manager.match(appBundleId: "com.apple.Safari", targetHost: "example.com")
        if case .proxy = action1 {
            XCTAssertTrue(true)
        } else {
            XCTFail("Should match app name")
        }
    }
}
