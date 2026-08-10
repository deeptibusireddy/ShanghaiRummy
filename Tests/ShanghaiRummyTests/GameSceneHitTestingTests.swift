import XCTest
@testable import ShanghaiRummy

@MainActor
final class GameSceneHitTestingTests: XCTestCase {
    func testMeldTargetHitTestingUsesRenderedTargetFrames() {
        let ownMeldId = UUID()
        let opponentMeldId = UUID()
        let targets = [
            ownMeldId: CGRect(x: 100, y: 40, width: 80, height: 50),
            opponentMeldId: CGRect(x: 320, y: 180, width: 90, height: 60),
        ]

        XCTAssertEqual(
            GameScene.meldTargetId(
                at: CGPoint(x: 140, y: 65),
                targetFrames: targets,
                eligibleIds: [ownMeldId, opponentMeldId]
            ),
            ownMeldId
        )
        XCTAssertEqual(
            GameScene.meldTargetId(
                at: CGPoint(x: 365, y: 210),
                targetFrames: targets,
                eligibleIds: [ownMeldId, opponentMeldId]
            ),
            opponentMeldId
        )
        XCTAssertNil(
            GameScene.meldTargetId(
                at: CGPoint(x: 250, y: 120),
                targetFrames: targets,
                eligibleIds: [ownMeldId, opponentMeldId]
            )
        )
    }

    func testOverlappingTargetsPreferEligibleThenNearestMeld() {
        let leftMeldId = UUID()
        let rightMeldId = UUID()
        let targets = [
            leftMeldId: CGRect(x: 100, y: 40, width: 80, height: 50),
            rightMeldId: CGRect(x: 170, y: 40, width: 80, height: 50),
        ]
        let overlapPoint = CGPoint(x: 174, y: 65)

        XCTAssertEqual(
            GameScene.meldTargetId(
                at: overlapPoint,
                targetFrames: targets,
                eligibleIds: [rightMeldId]
            ),
            rightMeldId,
            "An overlapping but incompatible target must not intercept the drop"
        )
        XCTAssertEqual(
            GameScene.meldTargetId(
                at: overlapPoint,
                targetFrames: targets,
                eligibleIds: [leftMeldId, rightMeldId]
            ),
            leftMeldId,
            "When both targets are valid, the nearest center should win"
        )
    }

    func testOverlappingHandFanAssignsEveryExposedSliceToItsCard() {
        let diamondFour = UUID()
        let clubFour = UUID()
        let firstSpadeFour = UUID()
        let secondSpadeFour = UUID()
        let slots: [(id: UUID, x: CGFloat, y: CGFloat)] = [
            (diamondFour, 100, 80),
            (clubFour, 127, 80),
            (firstSpadeFour, 154, 80),
            (secondSpadeFour, 181, 80),
        ]
        let cardSize = CGSize(width: 68, height: 96)

        XCTAssertEqual(
            GameScene.handCardId(
                at: CGPoint(x: 80, y: 80),
                slots: slots,
                cardSize: cardSize
            ),
            diamondFour
        )
        XCTAssertEqual(
            GameScene.handCardId(
                at: CGPoint(x: 105, y: 80),
                slots: slots,
                cardSize: cardSize
            ),
            clubFour
        )
        XCTAssertEqual(
            GameScene.handCardId(
                at: CGPoint(x: 132, y: 80),
                slots: slots,
                cardSize: cardSize
            ),
            firstSpadeFour
        )
        XCTAssertEqual(
            GameScene.handCardId(
                at: CGPoint(x: 170, y: 80),
                slots: slots,
                cardSize: cardSize
            ),
            secondSpadeFour
        )
    }
}
