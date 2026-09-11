import XCTest

/// 실제 탭/타이핑으로 로그인 → 홈 이동 → 탭 전환이 되는지 확인하는 테스트.
/// 시뮬레이터에 GUI가 없어서 사람이 직접 눌러볼 수 없는 환경이라, XCUITest로
/// 실제 터치 이벤트를 흉내내서 검증한다.
final class LoginFlowUITests: XCTestCase {
    func testLoginNavigatesHomeThenTabsStillWork() throws {
        let app = XCUIApplication()
        app.launch()

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 5), "탭바가 안 보임")

        // 마이페이지 탭으로 이동 -> 로그인 폼
        tabBar.buttons["마이페이지"].tap()
        let idField = app.textFields["아이디"]
        XCTAssertTrue(idField.waitForExistence(timeout: 5), "아이디 입력창이 안 보임")
        idField.tap()
        idField.typeText("admin1234")

        let pwField = app.secureTextFields["비밀번호"]
        XCTAssertTrue(pwField.waitForExistence(timeout: 2))
        pwField.tap()
        pwField.typeText("1234")

        app.buttons["로그인"].tap()

        // 로그인 성공하면 홈 탭으로 자동 이동해야 한다(PM 지시) -> 홈 화면 요소가 보이는지 확인
        let heroText = app.staticTexts["이런 리모델링\n가능하다고?"]
        XCTAssertTrue(heroText.waitForExistence(timeout: 5), "로그인 후 홈으로 안 옮겨짐")

        // 다시 마이페이지로 가면 프로필(로그아웃 버튼)이 보여야 한다
        tabBar.buttons["마이페이지"].tap()
        XCTAssertTrue(app.buttons["로그아웃"].waitForExistence(timeout: 5), "로그인 상태인데 프로필이 안 보임")

        // 버그 리포트 재현: 마이페이지에 있는 상태에서 다른 탭으로 이동이 되는지
        tabBar.buttons["저장"].tap()
        XCTAssertTrue(app.staticTexts["저장"].waitForExistence(timeout: 5), "마이페이지에서 저장 탭으로 전환 안 됨")

        tabBar.buttons["추천"].tap()
        XCTAssertTrue(app.staticTexts["홈"].waitForExistence(timeout: 5), "저장에서 추천 탭으로 전환 안 됨(추천 헤더는 '홈'이라는 라벨을 씀)")

        tabBar.buttons["홈"].tap()
        XCTAssertTrue(heroText.waitForExistence(timeout: 5), "추천에서 홈 탭으로 전환 안 됨")
    }
}
