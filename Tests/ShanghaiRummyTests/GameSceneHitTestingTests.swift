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

    func testOverlappingDiscardAndMeldUseNearestVisualTarget() {
        let meldId = UUID()
        let discard = CGRect(x: 100, y: 100, width: 100, height: 100)
        let melds = [
            meldId: CGRect(x: 160, y: 100, width: 80, height: 100),
        ]

        XCTAssertEqual(
            GameScene.preferredCardDropTarget(
                at: CGPoint(x: 170, y: 150),
                discardFrame: discard,
                meldTargetFrames: melds,
                eligibleIds: [meldId]
            ),
            .discard
        )
        XCTAssertEqual(
            GameScene.preferredCardDropTarget(
                at: CGPoint(x: 190, y: 150),
                discardFrame: discard,
                meldTargetFrames: melds,
                eligibleIds: [meldId]
            ),
            .meld(meldId)
        )
        XCTAssertEqual(
            GameScene.preferredCardDropTarget(
                at: CGPoint(x: 175, y: 150),
                discardFrame: discard,
                meldTargetFrames: melds,
                eligibleIds: [meldId]
            ),
            .meld(meldId),
            "An exact tie should favor the deliberate meld target"
        )
    }

    func testIneligibleOverlappingMeldCannotInterceptDiscard() {
        let meldId = UUID()

        XCTAssertEqual(
            GameScene.preferredCardDropTarget(
                at: CGPoint(x: 190, y: 150),
                discardFrame: CGRect(
                    x: 100,
                    y: 100,
                    width: 100,
                    height: 100
                ),
                meldTargetFrames: [
                    meldId: CGRect(
                        x: 160,
                        y: 100,
                        width: 80,
                        height: 100
                    ),
                ],
                eligibleIds: []
            ),
            .discard
        )
    }

    func testDiscardDropZoneTracksVisiblePileInsteadOfLargeHalo() {
        let zone = GameScene.discardDropZone(
            sceneSize: CGSize(width: 874, height: 402)
        )

        XCTAssertEqual(zone.width, 85.2, accuracy: 0.001)
        XCTAssertEqual(zone.height, 106.4, accuracy: 0.001)
    }

    func testOpponentMeldRowsStayReadableInsideCrowdedBounds() {
        let normalScale = GameScene.fittedMeldScale(
            cardCounts: [3, 4],
            desiredScale: 0.46,
            meldGap: 12,
            availableWidth: 180
        )
        XCTAssertEqual(normalScale, 0.46, accuracy: 0.001)

        let wrappedRowWidth = GameScene.meldRowWidth(
            cardCounts: [3, 3, 3],
            scale: 0.34,
            cardStepFraction: 0.50,
            meldGap: 8
        )
        XCTAssertLessThanOrEqual(wrappedRowWidth, 170.8)

        let compactStep = GameScene.fittedMeldStepFraction(
            cardCounts: [3, 5],
            scale: 0.34,
            desiredStepFraction: 0.50,
            meldGap: 8,
            availableWidth: 117.3
        )
        let compactRowWidth = GameScene.meldRowWidth(
            cardCounts: [3, 5],
            scale: 0.34,
            cardStepFraction: compactStep,
            meldGap: 8
        )
        XCTAssertGreaterThanOrEqual(compactStep, 0.25)
        XCTAssertLessThan(compactStep, 0.50)
        XCTAssertLessThanOrEqual(compactRowWidth, 117.301)

        let minimumStep = GameScene.fittedMeldStepFraction(
            cardCounts: [5, 5],
            scale: 0.34,
            desiredStepFraction: 0.50,
            meldGap: 8,
            availableWidth: 114.5
        )
        XCTAssertEqual(minimumStep, 0.25, accuracy: 0.001)
        XCTAssertLessThanOrEqual(
            GameScene.meldRowWidth(
                cardCounts: [5, 5],
                scale: 0.34,
                cardStepFraction: minimumStep,
                meldGap: 8
            ),
            114.5
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
