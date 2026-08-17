import XCTest
import UIKit
@testable import ShanghaiRummy

@MainActor
final class GameSceneHitTestingTests: XCTestCase {
    func testMidGameSceneDefersLayoutWhileUsingPlaceholderSize() {
        let vm = GameViewModel(state: GameFactory.demoMidGame())

        let scene = GameScene(
            size: CGSize(width: 1, height: 1),
            viewModel: vm
        )

        XCTAssertEqual(scene.size, CGSize(width: 1, height: 1))
    }

    func testLandscapeCutoutExpandsTableEdgeInsets() {
        let safeArea = UIEdgeInsets(
            top: 0,
            left: 59,
            bottom: 21,
            right: 21
        )

        XCTAssertEqual(
            GameScene.tableHorizontalEdgeInset(
                sceneWidth: 852,
                safeAreaInsets: safeArea
            ),
            67
        )
        XCTAssertEqual(
            GameScene.seatLayoutHorizontalInset(for: safeArea),
            74
        )
    }

    func testBuyDecisionRecognizesOnlySafeUtilityControls() {
        XCTAssertTrue(
            GameScene.isSafeUtilityControlDuringBuyDecision("sort-rank")
        )
        XCTAssertTrue(
            GameScene.isSafeUtilityControlDuringBuyDecision("sort-suit")
        )
        XCTAssertTrue(
            GameScene.isSafeUtilityControlDuringBuyDecision("show-score")
        )
        XCTAssertFalse(
            GameScene.isSafeUtilityControlDuringBuyDecision("stock")
        )
        XCTAssertFalse(
            GameScene.isSafeUtilityControlDuringBuyDecision("discard")
        )
        XCTAssertFalse(
            GameScene.isSafeUtilityControlDuringBuyDecision("save-meld")
        )
        XCTAssertFalse(
            GameScene.isSafeUtilityControlDuringBuyDecision("card:\(UUID())")
        )
    }

    func testReorderOnlyDragCannotBecomeGameplayDrop() {
        XCTAssertFalse(
            GameScene.allowsGameplayDrop(
                isLocalPlayersTurn: true,
                phase: .awaitingDraw,
                isBuyDecisionActive: true
            )
        )
        XCTAssertTrue(
            GameScene.allowsGameplayDrop(
                isLocalPlayersTurn: true,
                phase: .awaitingMeldOrDiscard,
                isBuyDecisionActive: false
            )
        )
        XCTAssertFalse(
            GameScene.allowsGameplayDrop(
                isLocalPlayersTurn: false,
                phase: .awaitingMeldOrDiscard,
                isBuyDecisionActive: false
            )
        )
    }

    func testCardTapAllowsSmallFingerDrift() {
        XCTAssertTrue(GameScene.isCardTap(dx: 12, dy: 8))
        XCTAssertTrue(GameScene.isCardTap(dx: 18, dy: 0))
        XCTAssertFalse(GameScene.isCardTap(dx: 18, dy: 1))
    }

    func testTapStagesOnlyWhileBuildingInitialContract() {
        XCTAssertTrue(
            GameScene.allowsTapToStage(
                isLocalPlayersTurn: true,
                phase: .awaitingMeldOrDiscard,
                isBuyDecisionActive: false,
                hasGoneDownThisRound: false
            )
        )
        XCTAssertFalse(
            GameScene.allowsTapToStage(
                isLocalPlayersTurn: true,
                phase: .awaitingMeldOrDiscard,
                isBuyDecisionActive: false,
                hasGoneDownThisRound: true
            )
        )
        XCTAssertFalse(
            GameScene.allowsTapToStage(
                isLocalPlayersTurn: false,
                phase: .awaitingMeldOrDiscard,
                isBuyDecisionActive: false,
                hasGoneDownThisRound: false
            )
        )
        XCTAssertFalse(
            GameScene.allowsTapToStage(
                isLocalPlayersTurn: true,
                phase: .awaitingDraw,
                isBuyDecisionActive: false,
                hasGoneDownThisRound: false
            )
        )
    }

    func testCardCountLabelUsesSingularOnlyForOne() {
        XCTAssertEqual(GameScene.cardCountLabel(0), "0 cards")
        XCTAssertEqual(GameScene.cardCountLabel(1), "1 card")
        XCTAssertEqual(GameScene.cardCountLabel(2), "2 cards")
    }

    func testTurnTitleUsesRoleForLocalPlayerAndNameForOthers() {
        XCTAssertEqual(
            GameScene.turnTitle(
                playerName: "You",
                isLocalPlayersTurn: true,
                isCPU: false
            ),
            "YOUR TURN"
        )
        XCTAssertEqual(
            GameScene.turnTitle(
                playerName: "Sam",
                isLocalPlayersTurn: false,
                isCPU: false
            ),
            "SAM'S TURN"
        )
        XCTAssertEqual(
            GameScene.turnTitle(
                playerName: "Bot",
                isLocalPlayersTurn: true,
                isCPU: true
            ),
            "BOT'S TURN"
        )
    }

    func testFiveAndSixPlayerSeatsUseCompactWidth() {
        XCTAssertEqual(
            GameScene.opponentSeatWidth(sceneWidth: 852, playerCount: 4),
            138
        )
        XCTAssertEqual(
            GameScene.opponentSeatWidth(sceneWidth: 852, playerCount: 5),
            112
        )
        XCTAssertEqual(
            GameScene.opponentSeatWidth(sceneWidth: 852, playerCount: 6),
            112
        )
        XCTAssertEqual(
            GameScene.opponentSeatWidth(sceneWidth: 700, playerCount: 4),
            64
        )
    }

    func testTurnBannerLeavesRoomForThreeUtilityControls() {
        let width = GameScene.turnBannerWidth(
            sceneWidth: 852,
            horizontalEdgeInset: 67
        )
        let bannerRightEdge = 852 / 2 + width / 2
        let scoreControlLeftEdge: CGFloat = 852 - 67 - 118 - 22

        XCTAssertEqual(width, 414)
        XCTAssertLessThanOrEqual(
            bannerRightEdge + 12,
            scoreControlLeftEdge
        )
    }

    func testSixPlayerTopMeldLanesStaySeparated() {
        let sceneSize = CGSize(width: 1366, height: 1024)
        let horizontalEdgeInset: CGFloat = 24
        let seatY = sceneSize.height - 24 - 60
        let scale = GameScene.expandedOpponentMeldScale
        let rowY = GameScene.centerTopMeldRowY(
            sceneSize: sceneSize,
            seatY: seatY,
            horizontalEdgeInset: horizontalEdgeInset,
            meldScale: scale
        )
        let meldTop = rowY + CardNode.size.height * scale / 2
        let bannerBottom = GameScene.turnBannerFrame(
            sceneSize: sceneSize,
            horizontalEdgeInset: horizontalEdgeInset
        ).minY
        let cornerRowY = GameScene.topCornerMeldRowY(
            sceneSize: sceneSize,
            seatY: seatY,
            horizontalEdgeInset: horizontalEdgeInset,
            playerCount: 6,
            cornerMeldScale: scale,
            centerMeldScale: scale
        )
        let centerMeldBottom = rowY - CardNode.size.height * scale / 2
        let cornerMeldTop = cornerRowY
            + CardNode.size.height * scale / 2

        XCTAssertLessThan(rowY, seatY)
        XCTAssertEqual(
            bannerBottom - meldTop,
            GameScene.topMeldBannerGap,
            accuracy: 0.001
        )
        XCTAssertEqual(
            centerMeldBottom - cornerMeldTop,
            GameScene.topMeldLaneGap,
            accuracy: 0.001
        )
    }

    func testFourPlayerTopMeldLaneStaysBelowTurnBanner() {
        let sceneSize = CGSize(width: 1024, height: 768)
        let horizontalEdgeInset: CGFloat = 24
        let seatY = sceneSize.height - 24 - 60
        let scale = GameScene.expandedOpponentMeldScale
        let rowY = GameScene.centerTopMeldRowY(
            sceneSize: sceneSize,
            seatY: seatY,
            horizontalEdgeInset: horizontalEdgeInset,
            meldScale: scale
        )
        let meldTop = rowY + CardNode.size.height * scale / 2
        let bannerBottom = GameScene.turnBannerFrame(
            sceneSize: sceneSize,
            horizontalEdgeInset: horizontalEdgeInset
        ).minY

        XCTAssertLessThan(rowY, seatY)
        XCTAssertEqual(
            bannerBottom - meldTop,
            GameScene.topMeldBannerGap,
            accuracy: 0.001
        )
    }

    func testSixPlayerStatusFixtureSeparatesLocalAndActivePlayers() {
        let state = GameFactory.demoSixPlayerStatus()

        XCTAssertEqual(state.players.count, 6)
        XCTAssertEqual(state.players[0].name, "You")
        XCTAssertEqual(state.players[state.currentTurnIndex].name, "Sam")
        XCTAssertNotEqual(state.currentPlayerId, state.players[0].id)
        XCTAssertEqual(
            state.melds.filter { $0.ownerId == state.currentPlayerId }.count,
            2
        )
    }

    func testContextAreaShowsOnlyRealEnabledActions() {
        XCTAssertFalse(
            GameScene.shouldDisplayContextAction(name: nil, enabled: false)
        )
        XCTAssertFalse(
            GameScene.shouldDisplayContextAction(
                name: "save-meld",
                enabled: false
            )
        )
        XCTAssertTrue(
            GameScene.shouldDisplayContextAction(
                name: "save-meld",
                enabled: true
            )
        )
    }

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

    func testExpandedIPadMeldWorkspacePreservesCompactFallbacks() {
        XCTAssertFalse(GameScene.usesExpandedIPadLayout(sceneHeight: 402))
        XCTAssertTrue(GameScene.usesExpandedIPadLayout(sceneHeight: 1024))
        XCTAssertEqual(
            GameScene.preferredOpponentMeldScale(sceneHeight: 402),
            0.62
        )
        XCTAssertEqual(
            GameScene.preferredOpponentMeldScale(sceneHeight: 1024),
            0.78
        )
        XCTAssertEqual(
            GameScene.preferredOwnMeldScale(sceneHeight: 402),
            0.68
        )
        XCTAssertEqual(
            GameScene.preferredOwnMeldScale(sceneHeight: 1024),
            0.86
        )
        XCTAssertEqual(GameScene.minimumMeldScale, 0.34)
        XCTAssertEqual(GameScene.stagingTrayHeight(sceneHeight: 402), 56)
        XCTAssertEqual(GameScene.stagingTrayHeight(sceneHeight: 1024), 112)
        XCTAssertEqual(GameScene.stagedCardScale(sceneHeight: 402), 0.44)
        XCTAssertEqual(GameScene.stagedCardScale(sceneHeight: 1024), 0.76)

        XCTAssertEqual(GameScene.ownMeldGap, 14)
        XCTAssertEqual(GameScene.ownMeldHandGap, 12)
        XCTAssertEqual(GameScene.stagingTrayHandGap, 8)
        XCTAssertEqual(GameScene.standardOpponentMeldGap, 12)
        XCTAssertEqual(GameScene.crowdedOpponentMeldGap, 8)
        XCTAssertEqual(GameScene.meldCardStepFraction, 0.50)
        XCTAssertEqual(GameScene.minimumMeldStepFraction, 0.25)

        let handRowY: CGFloat = 150
        let handCardHeight: CGFloat = 96
        let meldRowY = GameScene.ownMeldRowY(
            handRowY: handRowY,
            handCardHeight: handCardHeight,
            meldScale: GameScene.expandedOwnMeldScale
        )
        let handTop = handRowY + handCardHeight / 2
        let meldBottom = meldRowY
            - CardNode.size.height * GameScene.expandedOwnMeldScale / 2
        XCTAssertEqual(
            meldBottom - handTop,
            GameScene.ownMeldHandGap,
            accuracy: 0.001
        )

        let trayY = GameScene.stagingTrayY(
            handRowY: handRowY,
            handCardHeight: handCardHeight,
            sceneHeight: 1024
        )
        let trayBottom = trayY
            - GameScene.stagingTrayHeight(sceneHeight: 1024) / 2
        XCTAssertEqual(
            trayBottom - handTop,
            GameScene.stagingTrayHandGap,
            accuracy: 0.001
        )

        XCTAssertEqual(
            GameScene.greedyMeldRowIndices(
                cardCounts: [5, 5, 5],
                scale: GameScene.expandedOpponentMeldScale,
                meldGap: GameScene.crowdedOpponentMeldGap,
                availableWidth: 442
            ),
            [[0, 1], [2]]
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
