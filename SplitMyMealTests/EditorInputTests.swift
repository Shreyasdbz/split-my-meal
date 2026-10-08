import XCTest
import UIKit
@testable import SplitMyMeal_Prod_A

final class EditorInputTests: XCTestCase {
    func testLocalizedDecimalInputConsumesEntireString() throws {
        XCTAssertEqual(try DecimalInput.parse(" 12.34 ", allowZero: false, locale: Locale(identifier: "en_US")), 12.34)
        XCTAssertEqual(try DecimalInput.parse("12,34", allowZero: false, locale: Locale(identifier: "de_DE")), 12.34)
        XCTAssertEqual(try DecimalInput.parse("١٢٫٣٤", allowZero: false, locale: Locale(identifier: "ar_SA")), 12.34)
        XCTAssertEqual(try DecimalInput.parse(".50", allowZero: false, locale: Locale(identifier: "en_US")), 0.5)
        XCTAssertEqual(try DecimalInput.parse("8.875", allowZero: true, maximumFractionDigits: 4, locale: Locale(identifier: "en_US")), 8.875)
        XCTAssertEqual(try DecimalInput.parse("0", allowZero: true), 0)
        XCTAssertEqual(try DecimalInput.parse("8,875", allowZero: true, maximumFractionDigits: 4, locale: Locale(identifier: "de_DE")), 8.875)
        XCTAssertThrowsError(try DecimalInput.parse("1.000", allowZero: true, maximumFractionDigits: 4, locale: Locale(identifier: "de_DE")), "Grouped percentage input must not become one percent.")
        XCTAssertThrowsError(try DecimalInput.parse("1.000,5", allowZero: true, maximumFractionDigits: 4, locale: Locale(identifier: "de_DE")))
        XCTAssertThrowsError(try DecimalInput.parse("1,000", allowZero: true, maximumFractionDigits: 4, locale: Locale(identifier: "en_US")))
    }

    func testInvalidNumericInputNeverBecomesSuccessfulSaveValue() {
        for input in ["", " ", "0", "-2", "+2", "NaN", "inf", "12USD", "1,000.00", "1.234", "1.2.3", "1000000001"] {
            XCTAssertThrowsError(try DecimalInput.parse(input, allowZero: false, locale: Locale(identifier: "en_US")), input)
        }
    }

    func testChargeModeConversionUsesCurrentDraftAndCalculationBase() throws {
        XCTAssertEqual(try DecimalInput.convert(8.875, toPercentage: false, base: 120), 10.65, accuracy: 0.00001)
        XCTAssertEqual(try DecimalInput.convert(10.65, toPercentage: true, base: 120), 8.875, accuracy: 0.00001)
        XCTAssertEqual(try DecimalInput.convert(20, toPercentage: false, base: 130.65), 26.13, accuracy: 0.00001)
        XCTAssertEqual(try DecimalInput.convert(0.5, toPercentage: false, base: 1), 0.01, accuracy: 0.00001)
        XCTAssertEqual(Money.percentageCents(0.5, baseCents: 100), 1, "Preview and saved charges use the same half-up cent rounding.")
        XCTAssertEqual(try DecimalInput.convert(0, toPercentage: true, base: 0), 0)
        XCTAssertThrowsError(try DecimalInput.convert(5, toPercentage: true, base: 0))
        XCTAssertThrowsError(try DecimalInput.convert(.nan, toPercentage: false, base: 100))
        XCTAssertThrowsError(try DecimalInput.convert(5, toPercentage: false, base: -100))
    }

    func testReceiptRejectsUnreadableAndOversizedData() {
        XCTAssertThrowsError(try ReceiptPhoto.prepare(Data("not an image".utf8)))
        XCTAssertThrowsError(try ReceiptPhoto.prepare(Data(count: 40 * 1024 * 1024 + 1)))
        XCTAssertNil(ReceiptPhoto.preview(Data("not an image".utf8)))
        XCTAssertNil(ReceiptPhoto.preview(Data(count: 40 * 1024 * 1024 + 1)))
    }

    @MainActor
    func testReceiptDownsamplesAndKeepsReadableImage() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000), format: format).image { drawing in
            UIColor.white.setFill()
            drawing.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
            ("Receipt $42.50" as NSString).draw(at: CGPoint(x: 100, y: 100), withAttributes: [.font: UIFont.systemFont(ofSize: 80), .foregroundColor: UIColor.black])
        }
        let original = try XCTUnwrap(image.jpegData(compressionQuality: 0.95))
        let preview = try XCTUnwrap(ReceiptPhoto.preview(original, maximumPixelSize: 600)?.cgImage)
        XCTAssertEqual(max(preview.width, preview.height), 600)
        XCTAssertEqual(Double(preview.width) / Double(preview.height), 1.5, accuracy: 0.01)
        XCTAssertNil(ReceiptPhoto.preview(original, maximumPixelSize: 0))
        let prepared = try ReceiptPhoto.prepare(original)
        let decoded = try XCTUnwrap(UIImage(data: prepared)?.cgImage)
        XCTAssertEqual(max(decoded.width, decoded.height), 2400)
        XCTAssertEqual(Double(decoded.width) / Double(decoded.height), 1.5, accuracy: 0.01)
        XCTAssertLessThanOrEqual(prepared.count, 8 * 1024 * 1024)
    }
}
