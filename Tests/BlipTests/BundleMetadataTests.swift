import XCTest

final class BundleMetadataTests: XCTestCase {
    func testInfoPlistDeclaresBlipIcon() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: "Resources/Info.plist"))
        let plist = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(plist["CFBundleIconFile"] as? String, "Blip")
    }

    func testPackageScriptCopiesIconIntoAppResources() throws {
        let script = try String(contentsOfFile: "Scripts/package-app.sh", encoding: .utf8)
        XCTAssertTrue(script.contains("Contents/Resources"))
        XCTAssertTrue(script.contains("Resources/Blip.icns"))
    }
}
