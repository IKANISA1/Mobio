import Flutter
import app_links
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {

  func testColdConnectionForwardsURLAndOnlyBrowsingWebActivityOnce() {
    var received: [URL] = []
    let forwarder = MobioSceneLinkForwarder { received.append($0) }
    let invite = URL(string: "https://mobio.ikanisa.com/invite/MOBI482913")!
    let custom = URL(string: "mobio://biopay/nfc?type=momo_pay_code&receiver=123456")!
    let web = NSUserActivity(activityType: NSUserActivityTypeBrowsingWeb)
    web.webpageURL = invite
    let unrelated = NSUserActivity(activityType: "synthetic.unrelated")
    unrelated.webpageURL = URL(string: "https://unrelated.invalid/")!
    forwarder.forward(urls: [custom, invite], activities: [web, unrelated])
    XCTAssertEqual(received, [custom, invite])
    forwarder.forward(urls: [], activities: [web])
    XCTAssertEqual(received, [custom, invite, invite])
  }

  func testInstalledPluginRetainsColdLinkThenStreamsWarmLink() {
    let plugin = AppLinksIosPlugin()
    let cold = URL(string: "https://mobio.ikanisa.com/invite/MOBI482913")!
    let warm = URL(string: "https://mobio.ikanisa.com/biopay/pay/ABCDEFGHIJKLMNOPQRSTUVWX")!
    let forwarder = MobioSceneLinkForwarder { plugin.handleLink(url: $0) }
    forwarder.forward(urls: [cold], activities: [])
    var received: [String] = []
    XCTAssertNil(plugin.onListen(withArguments: nil, eventSink: { received.append($0 as! String) }))
    forwarder.forward(urls: [warm], activities: [])
    XCTAssertEqual(received, [cold.absoluteString, warm.absoluteString])
    XCTAssertNil(plugin.onCancel(withArguments: nil))
    XCTAssertNil(plugin.onListen(withArguments: nil, eventSink: { received.append($0 as! String) }))
    XCTAssertEqual(received.count, 2)
  }

}
