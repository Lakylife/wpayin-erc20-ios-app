//
//  Wpayin_WalletUITests.swift
//  Wpayin_WalletUITests
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import XCTest

final class Wpayin_WalletUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testCaptureReleaseScreenshots() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-screenshot-mode"]
        app.launch()

        XCTAssertTrue(app.buttons["Receive"].waitForExistence(timeout: 12))
        captureScreenshot(named: "03_home", app: app)

        app.buttons["Receive"].tap()
        XCTAssertTrue(app.navigationBars["Deposit"].waitForExistence(timeout: 5))
        captureScreenshot(named: "04_deposit", app: app)
        app.buttons["Close"].tap()

        XCTAssertTrue(app.buttons["Send"].waitForExistence(timeout: 5))
        app.buttons["Send"].tap()
        XCTAssertTrue(app.navigationBars["Withdraw"].waitForExistence(timeout: 5))
        captureScreenshot(named: "05_withdraw", app: app)
        app.buttons["Cancel"].tap()

        XCTAssertTrue(app.buttons["Swap"].waitForExistence(timeout: 5))
        let swapButtons = app.buttons.matching(identifier: "Swap")
        swapButtons.element(boundBy: swapButtons.count - 1).tap()
        XCTAssertTrue(app.staticTexts["You pay"].waitForExistence(timeout: 5))
        captureScreenshot(named: "06_swap", app: app)

        app.buttons["Activity"].tap()
        XCTAssertTrue(app.staticTexts["Transactions"].waitForExistence(timeout: 5))
        captureScreenshot(named: "07_activity", app: app)

        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Time Zone"].waitForExistence(timeout: 5))
        captureScreenshot(named: "08_settings", app: app)
    }

    private func captureScreenshot(named name: String, app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
