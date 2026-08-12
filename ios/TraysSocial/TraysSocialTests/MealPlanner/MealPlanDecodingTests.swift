@testable import TraysSocial
import XCTest

/// W178: decoding coverage for the meal-plan payloads.
///
/// The trap these exist for: `APIClient`'s decoder sets
/// `dateDecodingStrategy = .iso8601`, but the meal-plan API sends `week_start`
/// and `date` as bare `YYYY-MM-DD` calendar days with no time component, which
/// `.iso8601` rejects. Typing either field as `Date` therefore throws on the
/// *whole* payload — a failure that would otherwise only show up on device,
/// silently, as an empty planner (reads are D95-silent).
final class MealPlanDecodingTests: XCTestCase {
    /// Matches APIClient's decoder configuration (Services/APIClient.swift).
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func test_weekPayload_decodesBareCalendarDates() throws {
        let json = """
        {
          "data": {
            "week_start": "2026-03-02",
            "entries": [
              {
                "id": 41,
                "date": "2026-03-03",
                "post": {
                  "id": 7,
                  "caption": "Roast chicken. Serves four.",
                  "thumbnail_url": "/uploads/thumb.jpg",
                  "cooking_time_minutes": 75,
                  "type": "recipe"
                }
              }
            ]
          }
        }
        """

        let response = try decoder.decode(
            DataResponse<MealPlanWeekPayload>.self, from: Data(json.utf8)
        )

        XCTAssertEqual(response.data.weekStart, "2026-03-02")
        XCTAssertEqual(response.data.entries.count, 1)
        XCTAssertEqual(response.data.entries[0].date, "2026-03-03")
        XCTAssertEqual(response.data.entries[0].post.cookingTimeMinutes, 75)
        XCTAssertEqual(response.data.entries[0].post.title, "Roast chicken")
        XCTAssertFalse(response.data.entries[0].isPending)
    }

    /// The grocery endpoint's recipe summary omits `cooking_time_minutes` and
    /// `type` entirely — both must be optional or the payload throws.
    func test_groceryPayload_decodesTheShorterPostSummary() throws {
        let json = """
        {
          "data": {
            "week_start": "2026-03-02",
            "recipes": [
              {
                "post": {"id": 7, "caption": "Roast chicken", "thumbnail_url": null},
                "items": [
                  {"item_key": "7:1", "name": "Chicken", "quantity": "1", "unit": "whole", "checked": false},
                  {"item_key": "7:2", "name": "Salt", "quantity": null, "unit": null, "checked": true}
                ]
              }
            ]
          }
        }
        """

        let response = try decoder.decode(
            DataResponse<GroceryListPayload>.self, from: Data(json.utf8)
        )
        let items = response.data.recipes[0].items

        XCTAssertNil(response.data.recipes[0].post.cookingTimeMinutes)
        XCTAssertNil(response.data.recipes[0].post.type)
        XCTAssertEqual(items.map(\.itemKey), ["7:1", "7:2"])
        XCTAssertEqual(items[0].measure, "1 whole")
        XCTAssertNil(items[1].measure, "no quantity and no unit means no measure line at all")
        XCTAssertTrue(items[1].checked)
    }

    func test_createEntryBody_encodesSnakeCaseWithTheExactDay() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(CreateEntryBody(date: "2026-03-03", postId: 7))
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(decoded?["date"] as? String, "2026-03-03")
        XCTAssertEqual(decoded?["post_id"] as? Int, 7)
    }

    func test_groceryCheckBody_encodesSnakeCase() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        let data = try encoder.encode(
            GroceryCheckBody(weekStart: "2026-03-02", itemKey: "7:1", checked: true)
        )
        let decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(decoded?["week_start"] as? String, "2026-03-02")
        XCTAssertEqual(decoded?["item_key"] as? String, "7:1")
        XCTAssertEqual(decoded?["checked"] as? Bool, true)
    }

    /// Quantity and unit are joined verbatim — never parsed, converted, or
    /// summed. This test is the guard on that product rule.
    func test_measure_isVerbatimConcatenation() {
        let item = GroceryItem(
            itemKey: "7:1", name: "Flour", quantity: "1 1/2", unit: "cups", checked: false
        )

        XCTAssertEqual(item.measure, "1 1/2 cups")
    }
}
