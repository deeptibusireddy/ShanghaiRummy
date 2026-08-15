import Foundation
import GameKit
import UIKit
import Combine

@MainActor
final class GameCenterManager: NSObject, ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var displayName = ""
    @Published private(set) var lastError: String?
    @Published private(set) var hasActiveMatch = false
    @Published private(set) var onlineStatusMessage = ""
    @Published private(set) var onlineGame: GameViewModel?
    @Published private(set) var matchmakerNotice: String?
    @Published var isPresentingMatchmaker = false
    @Published var isPresentingAuthentication = false
    @Published private(set) var authenticationViewController: UIViewController?

    private var pendingInvite: GKInvite?
    private var quickPairSearchId: UUID?
    private var match: GKMatch?
    private var isChoosingHost = false
    private var authority: RealtimeGameAuthority?
    private var currentSnapshot: RealtimeGameSnapshot?
    private var pendingLocalRequestId: UUID?
    private var buyOfferTimeoutTask: Task<Void, Never>?
    private var gameSetup: RealtimeGameSetup?
    private var requestedRemoteHumanCount: Int?
    private var shouldBroadcastGameSetup = false
    private var isRunningHostedBots = false

    func authenticate() async {
        let localPlayer = GKLocalPlayer.local
        localPlayer.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let error {
                    self.lastError = error.localizedDescription
                    self.isAuthenticated = false
                    self.isPresentingAuthentication = false
                    self.authenticationViewController = nil
                    return
                }
                if let viewController {
                    self.authenticationViewController = viewController
                    self.isPresentingAuthentication = true
                    return
                }
                self.authenticationViewController = nil
                self.isPresentingAuthentication = false
                self.isAuthenticated = localPlayer.isAuthenticated
                self.displayName = localPlayer.displayName
                self.lastError = nil
                if localPlayer.isAuthenticated {
                    localPlayer.unregisterAllListeners()
                    localPlayer.register(self)
                }
            }
        }
    }

    func beginMatchmaking(invitedHumanCount: Int, botCount: Int) {
        guard isAuthenticated else {
            lastError = "Sign in to Game Center before starting an online game"
            return
        }
        guard invitedHumanCount >= 1,
              botCount >= 0,
              invitedHumanCount + botCount + 1 <= RulesConfig.maxPlayers else {
            lastError = "Choose 2–6 total human and bot players"
            return
        }
        gameSetup = RealtimeGameSetup(botCount: botCount)
        requestedRemoteHumanCount = invitedHumanCount
        shouldBroadcastGameSetup = true
        lastError = nil
        let people = invitedHumanCount == 1 ? "person" : "people"
        if botCount == 0 {
            matchmakerNotice = "Invite exactly \(invitedHumanCount) \(people)"
        } else {
            let bots = botCount == 1 ? "bot" : "bots"
            matchmakerNotice = "\(botCount) \(bots) reserved • Invite exactly "
                + "\(invitedHumanCount) \(people)"
        }
        isPresentingMatchmaker = true
    }

    func beginQuickPair() {
        guard isAuthenticated else {
            lastError = "Sign in to Game Center before starting an online game"
            return
        }
        let searchId = UUID()
        quickPairSearchId = searchId
        gameSetup = RealtimeGameSetup(botCount: 0)
        requestedRemoteHumanCount = nil
        shouldBroadcastGameSetup = false
        lastError = nil
        matchmakerNotice = nil
        hasActiveMatch = true
        onlineStatusMessage = "Looking for one other Quick Pair player…"

        let request = GKMatchRequest()
        request.minPlayers = RulesConfig.minPlayers
        request.maxPlayers = RulesConfig.minPlayers
        request.defaultNumberOfPlayers = RulesConfig.minPlayers
        request.playerGroup = RealtimeMessageCodec.playerGroup(botCount: 0)

        Task { [weak self] in
            do {
                let match = try await GKMatchmaker.shared().findMatch(
                    for: request
                )
                guard let self, self.quickPairSearchId == searchId else {
                    match.disconnect()
                    return
                }
                self.quickPairSearchId = nil
                GKMatchmaker.shared().finishMatchmaking(for: match)
                self.accept(match: match)
            } catch {
                guard let self, self.quickPairSearchId == searchId else {
                    return
                }
                self.quickPairSearchId = nil
                self.resetOnlineSession()
                self.lastError = "Quick Pair failed: \(error.localizedDescription)"
            }
        }
    }

    func makeMatchmakerViewController() -> GKMatchmakerViewController? {
        let controller: GKMatchmakerViewController?
        if let invite = pendingInvite {
            pendingInvite = nil
            controller = GKMatchmakerViewController(invite: invite)
        } else {
            guard let requestedRemoteHumanCount else {
                lastError = "Choose the human seats before opening Game Center"
                return nil
            }
            let botCount = gameSetup?.botCount ?? 0
            let gameCenterPlayerCount = requestedRemoteHumanCount + 1
            let request = GKMatchRequest()
            request.minPlayers = gameCenterPlayerCount
            request.maxPlayers = gameCenterPlayerCount
            request.defaultNumberOfPlayers = gameCenterPlayerCount
            request.playerGroup = RealtimeMessageCodec.playerGroup(
                botCount: botCount
            )
            request.inviteMessage = botCount == 0
                ? "Join my Shanghai Rummy table"
                : "Join my Shanghai Rummy table — \(botCount) bot "
                    + (botCount == 1 ? "seat" : "seats")
                    + " reserved"
            request.recipientResponseHandler = { [weak self] player, response in
                Task { @MainActor in
                    self?.handleInvitationResponse(
                        response,
                        from: player.displayName
                    )
                }
            }
            controller = GKMatchmakerViewController(matchRequest: request)
        }
        controller?.matchmakerDelegate = self
        return controller
    }

    private func handleInvitationResponse(
        _ response: GKInviteRecipientResponse,
        from playerName: String
    ) {
        var message: String
        let isFailure: Bool
        switch response {
        case .accepted:
            message = "\(playerName) accepted the invitation"
            isFailure = false
        case .declined:
            message = "\(playerName) declined the invitation"
            isFailure = true
        case .failed:
            message = "Game Center could not deliver the invitation to \(playerName). Try Quick Pair on both phones."
            isFailure = true
        case .incompatible:
            message = "\(playerName) is not running a compatible build"
            isFailure = true
        case .unableToConnect:
            message = "Game Center could not contact \(playerName)"
            isFailure = true
        case .noAnswer:
            message = "\(playerName) did not answer the invitation"
            isFailure = true
        @unknown default:
            message = "Game Center returned an unknown invitation response"
            isFailure = true
        }
        if let botCount = gameSetup?.botCount, botCount > 0 {
            message += " • \(botCount) bot "
                + (botCount == 1 ? "seat" : "seats")
                + " reserved"
        }
        matchmakerNotice = message
        if isFailure {
            lastError = message
        }
    }

    func leaveOnlineMatch() {
        if quickPairSearchId != nil {
            GKMatchmaker.shared().cancel()
            quickPairSearchId = nil
        }
        match?.disconnect()
        resetOnlineSession()
    }

    private func accept(match: GKMatch) {
        self.match?.disconnect()
        self.match = match
        requestedRemoteHumanCount = nil
        match.delegate = self
        hasActiveMatch = true
        isChoosingHost = false
        currentSnapshot = nil
        authority = nil
        pendingLocalRequestId = nil
        onlineGame = nil
        onlineStatusMessage = match.expectedPlayerCount > 0
            ? "Waiting for \(match.expectedPlayerCount) more player(s)…"
            : "Connecting everyone…"
        if gameSetup == nil {
            sendToAll(.setupRequest)
        } else {
            broadcastGameSetupIfNeeded()
        }
        tryStartMatchIfReady()
    }

    private func tryStartMatchIfReady() {
        guard let match,
              match.expectedPlayerCount == 0,
              currentSnapshot == nil,
              !isChoosingHost else {
            return
        }
        let allPlayers = connectedPlayers(in: match)
        guard allPlayers.count >= RulesConfig.minPlayers else {
            onlineStatusMessage = "Waiting for players to connect…"
            return
        }
        guard let gameSetup else {
            onlineStatusMessage = "Waiting for the table options…"
            return
        }
        guard allPlayers.count + gameSetup.botCount
                <= RulesConfig.maxPlayers else {
            failOnlineSession("The selected people and bots exceed six seats")
            return
        }

        isChoosingHost = true
        onlineStatusMessage = "Starting the shared table…"
        match.chooseBestHostingPlayer { [weak self, weak match] selectedHost in
            Task { @MainActor in
                guard let self, let match, self.match === match else { return }
                self.isChoosingHost = false
                let players = self.connectedPlayers(in: match)
                let hostId = selectedHost?.gamePlayerID
                    ?? players.map(\.gamePlayerID).sorted().first
                guard let hostId else {
                    self.failOnlineSession("Game Center could not choose a host")
                    return
                }
                if hostId == GKLocalPlayer.local.gamePlayerID {
                    guard let gameSetup = self.gameSetup else {
                        self.failOnlineSession(
                            "The host did not receive the table options"
                        )
                        return
                    }
                    self.startHostedGame(
                        players: players,
                        botCount: gameSetup.botCount,
                        hostGamePlayerId: hostId
                    )
                } else {
                    self.onlineStatusMessage = "Waiting for the host to deal…"
                }
            }
        }
    }

    private func connectedPlayers(in match: GKMatch) -> [GKPlayer] {
        ([GKLocalPlayer.local] + match.players)
            .reduce(into: [String: GKPlayer]()) { players, player in
                players[player.gamePlayerID] = player
            }
            .values
            .sorted { $0.gamePlayerID < $1.gamePlayerID }
    }

    private func startHostedGame(
        players: [GKPlayer],
        botCount: Int,
        hostGamePlayerId: String
    ) {
        guard players.count >= RulesConfig.minPlayers,
              players.count + botCount <= RulesConfig.maxPlayers else {
            failOnlineSession("Online games require 2–6 connected players")
            return
        }

        let botNames = (0..<botCount).map { "Bot \($0 + 1)" }
        let state = GameFactory.newGame(
            playerNames: players.map(\.displayName) + botNames,
            seed: UInt64.random(in: 0...UInt64.max)
        )
        let humanStatePlayers = state.players.prefix(players.count)
        let bindings = zip(players, humanStatePlayers).map { gamePlayer, player in
            RealtimeParticipantBinding(
                gamePlayerId: gamePlayer.gamePlayerID,
                playerId: player.id,
                displayName: gamePlayer.displayName
            )
        }
        let botPlayerIds = state.players
            .dropFirst(players.count)
            .map(\.id)
        let snapshot = RealtimeGameSnapshot(
            revision: 0,
            state: state,
            participants: bindings,
            botPlayerIds: botPlayerIds,
            hostGamePlayerId: hostGamePlayerId
        )
        authority = RealtimeGameAuthority(snapshot: snapshot)
        install(snapshot)
        sendToAll(.start(snapshot))
        runHostedBotsIfNeeded()
    }

    private func install(_ snapshot: RealtimeGameSnapshot) {
        guard isValid(snapshot),
              let localBinding = snapshot.binding(
                forGamePlayerId: GKLocalPlayer.local.gamePlayerID
              ) else {
            failOnlineSession("The shared table data is invalid")
            return
        }
        if let currentSnapshot,
           snapshot.revision < currentSnapshot.revision {
            return
        }

        currentSnapshot = snapshot
        if let onlineGame {
            onlineGame.cpuPlayerIds = Set(snapshot.botPlayerIds)
            let completesPendingAction =
                snapshot.lastAppliedRequestId == pendingLocalRequestId
                && pendingLocalRequestId != nil
            if completesPendingAction {
                pendingLocalRequestId = nil
            }
            onlineGame.receiveAuthoritativeState(
                snapshot.state,
                completesPendingAction: completesPendingAction
            )
        } else {
            let viewModel = GameViewModel(
                state: snapshot.state,
                localPlayerId: localBinding.playerId
            )
            viewModel.configureOnlineActionSubmitter { [weak self] action in
                self?.submit(action) ?? false
            }
            viewModel.cpuPlayerIds = Set(snapshot.botPlayerIds)
            onlineGame = viewModel
        }
        onlineStatusMessage = "Connected"
        scheduleBuyOfferTimeout(for: snapshot)
    }

    private func scheduleBuyOfferTimeout(
        for snapshot: RealtimeGameSnapshot
    ) {
        buyOfferTimeoutTask?.cancel()
        buyOfferTimeoutTask = nil

        guard snapshot.hostGamePlayerId
                == GKLocalPlayer.local.gamePlayerID,
              snapshot.state.phase == .awaitingDraw,
              let offeredPlayerId = snapshot.state.buyDecisionPlayerId,
              !snapshot.botPlayerIds.contains(offeredPlayerId),
              offeredPlayerId != snapshot.state.currentPlayerId else {
            return
        }

        let expectedRevision = snapshot.revision
        buyOfferTimeoutTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(
                    for: .seconds(RulesConfig.buyOfferTimeoutSeconds)
                )
            } catch {
                return
            }
            guard let self,
                  self.currentSnapshot?.revision == expectedRevision,
                  self.currentSnapshot?.state.buyDecisionPlayerId
                    == offeredPlayerId,
                  var authority = self.authority,
                  let next = authority.passTimedOutBuyOffer(
                      playerId: offeredPlayerId,
                      expectedRevision: expectedRevision
                  ) else {
                return
            }
            self.buyOfferTimeoutTask = nil
            self.authority = authority
            self.install(next)
            self.sendToAll(.snapshot(next))
            self.runHostedBotsIfNeeded()
        }
    }

    private func isValid(_ snapshot: RealtimeGameSnapshot) -> Bool {
        let stateIds = snapshot.state.players.map(\.id)
        let decisionIsValid: Bool
        if snapshot.state.phase == .awaitingDraw {
            decisionIsValid = snapshot.state.buyDecisionPlayerId.map {
                stateIds.contains($0)
            } == true
        } else {
            decisionIsValid = snapshot.state.buyDecisionPlayerId == nil
        }
        return snapshot.hasValidPlayerIdentityLayout()
            && decisionIsValid
    }

    private func submit(_ action: TurnEngine.Action) -> Bool {
        guard let match, let snapshot = currentSnapshot else {
            lastError = "The online table is not connected"
            return false
        }
        let request = RealtimeActionRequest(
            expectedRevision: snapshot.revision,
            action: action
        )
        pendingLocalRequestId = request.id
        if snapshot.hostGamePlayerId == GKLocalPlayer.local.gamePlayerID {
            return applyAsHost(request, senderId: GKLocalPlayer.local.gamePlayerID)
        }
        guard let host = match.players.first(where: {
            $0.gamePlayerID == snapshot.hostGamePlayerId
        }) else {
            pendingLocalRequestId = nil
            onlineGame?.rejectOnlineAction(
                message: "The host is no longer connected",
                state: snapshot.state
            )
            return false
        }
        do {
            let data = try RealtimeMessageCodec.encode(.action(request))
            try match.send(data, to: [host], dataMode: .reliable)
            return true
        } catch {
            pendingLocalRequestId = nil
            onlineGame?.rejectOnlineAction(
                message: error.localizedDescription,
                state: snapshot.state
            )
            return false
        }
    }

    private func applyAsHost(
        _ request: RealtimeActionRequest,
        senderId: String
    ) -> Bool {
        guard var authority else {
            pendingLocalRequestId = nil
            failOnlineSession("The authoritative table is unavailable")
            return false
        }
        let result = authority.apply(request, fromGamePlayerId: senderId)
        self.authority = authority

        switch result {
        case .success(let snapshot):
            install(snapshot)
            sendToAll(.snapshot(snapshot))
            runHostedBotsIfNeeded()
            return true
        case .failure(let rejection):
            if senderId == GKLocalPlayer.local.gamePlayerID {
                pendingLocalRequestId = nil
                onlineGame?.rejectOnlineAction(
                    message: rejection.message,
                    state: rejection.currentSnapshot.state
                )
            } else {
                send(.rejection(rejection), toGamePlayerId: senderId)
            }
            return false
        }
    }

    private func handle(
        _ message: RealtimeGameMessage,
        from sender: GKPlayer
    ) {
        switch message {
        case .setupRequest:
            guard currentSnapshot == nil else { return }
            broadcastGameSetupIfNeeded()
        case .setup(let setup):
            guard currentSnapshot == nil else {
                return
            }
            guard (0...(RulesConfig.maxPlayers - RulesConfig.minPlayers))
                    .contains(setup.botCount) else {
                abortOnlineSession("Players received invalid table options")
                return
            }
            if let gameSetup, gameSetup != setup {
                abortOnlineSession("Players received conflicting table options")
                return
            }
            gameSetup = setup
            tryStartMatchIfReady()
        case .start(let snapshot):
            guard sender.gamePlayerID == snapshot.hostGamePlayerId else { return }
            if let gameSetup,
               gameSetup.botCount != snapshot.botPlayerIds.count {
                abortOnlineSession("The host started with different table options")
                return
            }
            gameSetup = RealtimeGameSetup(
                botCount: snapshot.botPlayerIds.count
            )
            shouldBroadcastGameSetup = false
            install(snapshot)
        case .action(let request):
            guard currentSnapshot?.hostGamePlayerId
                    == GKLocalPlayer.local.gamePlayerID else {
                return
            }
            _ = applyAsHost(request, senderId: sender.gamePlayerID)
        case .snapshot(let snapshot):
            guard sender.gamePlayerID == snapshot.hostGamePlayerId,
                  currentSnapshot?.hostGamePlayerId == snapshot.hostGamePlayerId
                    || currentSnapshot == nil else {
                return
            }
            install(snapshot)
        case .rejection(let rejection):
            guard sender.gamePlayerID
                    == rejection.currentSnapshot.hostGamePlayerId,
                  currentSnapshot?.hostGamePlayerId == sender.gamePlayerID,
                  isValid(rejection.currentSnapshot),
                  rejection.requestId == pendingLocalRequestId else {
                return
            }
            pendingLocalRequestId = nil
            let latestSnapshot: RealtimeGameSnapshot
            if let currentSnapshot,
               currentSnapshot.revision > rejection.currentSnapshot.revision {
                latestSnapshot = currentSnapshot
            } else {
                latestSnapshot = rejection.currentSnapshot
                currentSnapshot = rejection.currentSnapshot
            }
            onlineGame?.rejectOnlineAction(
                message: rejection.message,
                state: latestSnapshot.state
            )
        }
    }

    private func sendToAll(_ message: RealtimeGameMessage) {
        guard let match else { return }
        do {
            let data = try RealtimeMessageCodec.encode(message)
            try match.sendData(toAllPlayers: data, with: .reliable)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func send(
        _ message: RealtimeGameMessage,
        toGamePlayerId playerId: String
    ) {
        guard let match,
              let player = match.players.first(where: {
                  $0.gamePlayerID == playerId
              }) else {
            return
        }
        do {
            let data = try RealtimeMessageCodec.encode(message)
            try match.send(data, to: [player], dataMode: .reliable)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func failOnlineSession(_ message: String) {
        pendingLocalRequestId = nil
        lastError = message
        onlineStatusMessage = message
        if let onlineGame {
            onlineGame.rejectOnlineAction(
                message: message,
                state: currentSnapshot?.state ?? onlineGame.state
            )
        }
    }

    private func abortOnlineSession(_ message: String) {
        match?.delegate = nil
        match?.disconnect()
        resetOnlineSession()
        lastError = message
    }

    private func resetOnlineSession() {
        match?.delegate = nil
        match = nil
        authority = nil
        currentSnapshot = nil
        pendingLocalRequestId = nil
        buyOfferTimeoutTask?.cancel()
        buyOfferTimeoutTask = nil
        quickPairSearchId = nil
        gameSetup = nil
        requestedRemoteHumanCount = nil
        shouldBroadcastGameSetup = false
        isRunningHostedBots = false
        onlineGame = nil
        hasActiveMatch = false
        isChoosingHost = false
        matchmakerNotice = nil
        onlineStatusMessage = ""
    }

    private func broadcastGameSetupIfNeeded() {
        guard shouldBroadcastGameSetup, let gameSetup else { return }
        sendToAll(.setup(gameSetup))
    }

    private func runHostedBotsIfNeeded() {
        guard !isRunningHostedBots,
              var authority,
              authority.snapshot.hostGamePlayerId
                == GKLocalPlayer.local.gamePlayerID else {
            return
        }

        isRunningHostedBots = true
        defer { isRunningHostedBots = false }
        var actionCount = 0

        while actionCount < 200 {
            let snapshot = authority.snapshot
            guard let action = RealtimeBotDriver.nextAction(
                in: snapshot
            ) else {
                break
            }

            switch authority.applyBotAction(action) {
            case .success(let next):
                actionCount += 1
                self.authority = authority
                install(next)
                guard currentSnapshot?.revision == next.revision else {
                    return
                }
                sendToAll(.snapshot(next))
            case .failure(let error):
                self.authority = authority
                failOnlineSession(
                    "A bot could not continue the game: \(error.description)"
                )
                return
            }
        }

        self.authority = authority
        if actionCount == 200,
           RealtimeBotDriver.nextAction(in: authority.snapshot) != nil {
            failOnlineSession("A bot took too many actions without ending its turn")
        }
    }
}

extension GameCenterManager: GKMatchmakerViewControllerDelegate {
    nonisolated func matchmakerViewControllerWasCancelled(
        _ viewController: GKMatchmakerViewController
    ) {
        Task { @MainActor [weak self] in
            self?.isPresentingMatchmaker = false
            self?.matchmakerNotice = nil
            self?.gameSetup = nil
            self?.requestedRemoteHumanCount = nil
            self?.shouldBroadcastGameSetup = false
        }
    }

    nonisolated func matchmakerViewController(
        _ viewController: GKMatchmakerViewController,
        didFailWithError error: Error
    ) {
        Task { @MainActor [weak self] in
            self?.isPresentingMatchmaker = false
            self?.matchmakerNotice = nil
            self?.lastError = error.localizedDescription
            self?.gameSetup = nil
            self?.requestedRemoteHumanCount = nil
            self?.shouldBroadcastGameSetup = false
        }
    }

    nonisolated func matchmakerViewController(
        _ viewController: GKMatchmakerViewController,
        didFind match: GKMatch
    ) {
        Task { @MainActor [weak self] in
            self?.isPresentingMatchmaker = false
            self?.matchmakerNotice = nil
            self?.accept(match: match)
        }
    }
}

extension GameCenterManager: GKMatchDelegate {
    nonisolated func match(
        _ match: GKMatch,
        didReceive data: Data,
        fromRemotePlayer player: GKPlayer
    ) {
        do {
            let message = try RealtimeMessageCodec.decode(data)
            Task { @MainActor [weak self] in
                guard self?.match === match else { return }
                self?.handle(message, from: player)
            }
        } catch {
            Task { @MainActor [weak self] in
                self?.lastError = "Could not read an online game update"
            }
        }
    }

    nonisolated func match(
        _ match: GKMatch,
        player: GKPlayer,
        didChange state: GKPlayerConnectionState
    ) {
        Task { @MainActor [weak self] in
            guard let self, self.match === match else { return }
            switch state {
            case .connected:
                if let snapshot = self.currentSnapshot,
                   snapshot.hostGamePlayerId
                    == GKLocalPlayer.local.gamePlayerID {
                    self.send(.snapshot(snapshot), toGamePlayerId: player.gamePlayerID)
                } else {
                    if self.gameSetup == nil {
                        self.sendToAll(.setupRequest)
                    } else {
                        self.broadcastGameSetupIfNeeded()
                    }
                    self.tryStartMatchIfReady()
                }
            case .disconnected:
                self.onlineStatusMessage = "\(player.displayName) disconnected"
                if self.currentSnapshot?.hostGamePlayerId == player.gamePlayerID,
                   let onlineGame = self.onlineGame {
                    self.pendingLocalRequestId = nil
                    onlineGame.rejectOnlineAction(
                        message: "The table host disconnected",
                        state: self.currentSnapshot?.state ?? onlineGame.state
                    )
                } else {
                    self.onlineGame?.reportOnlineIssue(
                        "\(player.displayName) disconnected from the table"
                    )
                }
            case .unknown:
                break
            @unknown default:
                break
            }
        }
    }

    nonisolated func match(_ match: GKMatch, didFailWithError error: Error?) {
        Task { @MainActor [weak self] in
            guard let self, self.match === match else { return }
            self.failOnlineSession(
                error?.localizedDescription ?? "The online match disconnected"
            )
        }
    }
}

extension GameCenterManager: GKLocalPlayerListener {
    nonisolated func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.pendingInvite = invite
            self.gameSetup = nil
            self.requestedRemoteHumanCount = nil
            self.shouldBroadcastGameSetup = false
            self.isPresentingMatchmaker = true
        }
    }
}
