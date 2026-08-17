import Foundation

struct RealtimeParticipantBinding: Codable, Equatable, Sendable {
    let gamePlayerId: String
    let playerId: UUID
    let displayName: String
}

struct RealtimeGameSetup: Codable, Equatable, Sendable {
    let botCount: Int
}

struct RealtimeGameSnapshot: Codable, Equatable, Sendable {
    let revision: Int
    let state: GameState
    let participants: [RealtimeParticipantBinding]
    let botPlayerIds: [UUID]
    let hostGamePlayerId: String
    let lastAppliedRequestId: UUID?

    init(
        revision: Int,
        state: GameState,
        participants: [RealtimeParticipantBinding],
        botPlayerIds: [UUID] = [],
        hostGamePlayerId: String,
        lastAppliedRequestId: UUID? = nil
    ) {
        self.revision = revision
        self.state = state
        self.participants = participants
        self.botPlayerIds = botPlayerIds
        self.hostGamePlayerId = hostGamePlayerId
        self.lastAppliedRequestId = lastAppliedRequestId
    }

    func binding(forGamePlayerId id: String) -> RealtimeParticipantBinding? {
        participants.first(where: { $0.gamePlayerId == id })
    }

    func hasValidPlayerIdentityLayout() -> Bool {
        let participantIds = participants.map(\.playerId)
        let gamePlayerIds = participants.map(\.gamePlayerId)
        let stateIds = state.players.map(\.id)
        let participantIdSet = Set(participantIds)
        let botIdSet = Set(botPlayerIds)

        return participants.count >= RulesConfig.minPlayers
            && state.players.count >= RulesConfig.minPlayers
            && state.players.count <= RulesConfig.maxPlayers
            && botPlayerIds.count
                <= RulesConfig.maxPlayers - RulesConfig.minPlayers
            && participantIdSet.count == participantIds.count
            && Set(gamePlayerIds).count == gamePlayerIds.count
            && botIdSet.count == botPlayerIds.count
            && Set(stateIds).count == stateIds.count
            && participantIdSet.isDisjoint(with: botIdSet)
            && participantIdSet.union(botIdSet) == Set(stateIds)
            && participants.contains {
                $0.gamePlayerId == hostGamePlayerId
            }
    }
}

struct RealtimeActionRequest: Codable, Equatable, Sendable {
    let id: UUID
    let expectedRevision: Int
    let action: TurnEngine.Action

    init(
        id: UUID = UUID(),
        expectedRevision: Int,
        action: TurnEngine.Action
    ) {
        self.id = id
        self.expectedRevision = expectedRevision
        self.action = action
    }
}

struct RealtimeActionRejection: Codable, Equatable, Error, Sendable {
    enum Reason: String, Codable, Sendable {
        case staleState
        case unknownParticipant
        case actorMismatch
        case illegalAction
    }

    let requestId: UUID
    let reason: Reason
    let message: String
    let currentSnapshot: RealtimeGameSnapshot
}

enum RealtimeGameMessage: Codable, Equatable, Sendable {
    case setupRequest
    case setup(RealtimeGameSetup)
    case start(RealtimeGameSnapshot)
    case action(RealtimeActionRequest)
    case snapshot(RealtimeGameSnapshot)
    case rejection(RealtimeActionRejection)
}

enum RealtimeMessageCodec {
    static let protocolVersion = 4

    static func playerGroup(botCount: Int) -> Int {
        protocolVersion * 10 + botCount
    }

    private struct Envelope: Codable {
        let protocolVersion: Int
        let message: RealtimeGameMessage
    }

    enum CodecError: Error, Equatable {
        case unsupportedProtocolVersion(Int)
    }

    static func encode(_ message: RealtimeGameMessage) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(
            Envelope(protocolVersion: protocolVersion, message: message)
        )
    }

    static func decode(_ data: Data) throws -> RealtimeGameMessage {
        let envelope = try PropertyListDecoder().decode(Envelope.self, from: data)
        guard envelope.protocolVersion == protocolVersion else {
            throw CodecError.unsupportedProtocolVersion(envelope.protocolVersion)
        }
        return envelope.message
    }
}

enum RealtimeBotActionError: Error, Equatable, CustomStringConvertible {
    case actorIsNotBot
    case illegalAction(TurnEngine.ActionError)

    var description: String {
        switch self {
        case .actorIsNotBot:
            return "The requested player is not a bot"
        case .illegalAction(let error):
            return error.description
        }
    }
}

enum RealtimeBotDriver {
    static func nextAction(
        in snapshot: RealtimeGameSnapshot
    ) -> TurnEngine.Action? {
        guard snapshot.state.phase == .awaitingDraw
                || snapshot.state.phase == .awaitingMeldOrDiscard,
              snapshot.botPlayerIds.contains(
                snapshot.state.activePlayerId
              ) else {
            return nil
        }
        return CPUPlayer.nextAction(
            for: snapshot.state.activePlayerId,
            in: snapshot.state
        )
    }
}

struct RealtimeGameAuthority {
    private(set) var snapshot: RealtimeGameSnapshot

    init(snapshot: RealtimeGameSnapshot) {
        self.snapshot = snapshot
    }

    mutating func apply(
        _ request: RealtimeActionRequest,
        fromGamePlayerId senderId: String
    ) -> Result<RealtimeGameSnapshot, RealtimeActionRejection> {
        guard let binding = snapshot.binding(forGamePlayerId: senderId) else {
            return .failure(
                rejection(
                    request,
                    reason: .unknownParticipant,
                    message: "The sender is not part of this match"
                )
            )
        }
        let ownsAction = binding.playerId == request.action.actorPlayerId
        guard ownsAction || canRequestBotDealerAdvance(request.action) else {
            return .failure(
                rejection(
                    request,
                    reason: .actorMismatch,
                    message: "A player can submit only their own actions"
                )
            )
        }
        guard request.expectedRevision == snapshot.revision else {
            return .failure(
                rejection(
                    request,
                    reason: .staleState,
                    message: "The table changed before this action arrived"
                )
            )
        }

        switch TurnEngine.apply(request.action, to: snapshot.state) {
        case .failure(let error):
            return .failure(
                rejection(
                    request,
                    reason: .illegalAction,
                    message: error.description
                )
            )
        case .success(let state):
            let next = advance(
                to: state,
                lastAppliedRequestId: request.id
            )
            return .success(next)
        }
    }

    mutating func applyBotAction(
        _ action: TurnEngine.Action
    ) -> Result<RealtimeGameSnapshot, RealtimeBotActionError> {
        guard snapshot.botPlayerIds.contains(action.actorPlayerId) else {
            return .failure(.actorIsNotBot)
        }

        switch TurnEngine.apply(action, to: snapshot.state) {
        case .failure(let error):
            return .failure(.illegalAction(error))
        case .success(let state):
            return .success(
                advance(to: state, lastAppliedRequestId: nil)
            )
        }
    }

    mutating func passTimedOutBuyOffer(
        playerId: UUID,
        expectedRevision: Int
    ) -> RealtimeGameSnapshot? {
        guard snapshot.revision == expectedRevision,
              snapshot.state.phase == .awaitingDraw,
              snapshot.state.buyDecisionPlayerId == playerId,
              playerId != snapshot.state.currentPlayerId,
              case .success(let state) = TurnEngine.apply(
                  .passBuyOffer(playerId: playerId),
                  to: snapshot.state
              ) else {
            return nil
        }
        return advance(to: state, lastAppliedRequestId: nil)
    }

    private mutating func advance(
        to state: GameState,
        lastAppliedRequestId: UUID?
    ) -> RealtimeGameSnapshot {
        let next = RealtimeGameSnapshot(
            revision: snapshot.revision + 1,
            state: state,
            participants: snapshot.participants,
            botPlayerIds: snapshot.botPlayerIds,
            hostGamePlayerId: snapshot.hostGamePlayerId,
            lastAppliedRequestId: lastAppliedRequestId
        )
        snapshot = next
        return next
    }

    private func rejection(
        _ request: RealtimeActionRequest,
        reason: RealtimeActionRejection.Reason,
        message: String
    ) -> RealtimeActionRejection {
        RealtimeActionRejection(
            requestId: request.id,
            reason: reason,
            message: message,
            currentSnapshot: snapshot
        )
    }

    private func canRequestBotDealerAdvance(
        _ action: TurnEngine.Action
    ) -> Bool {
        guard snapshot.state.phase == .roundEnded,
              snapshot.botPlayerIds.contains(action.actorPlayerId),
              snapshot.state.nextDealer.id == action.actorPlayerId,
              case .advanceHand(let playerId) = action else {
            return false
        }
        return playerId == action.actorPlayerId
    }
}
