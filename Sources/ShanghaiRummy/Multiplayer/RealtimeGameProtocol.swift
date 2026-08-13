import Foundation

struct RealtimeParticipantBinding: Codable, Equatable, Sendable {
    let gamePlayerId: String
    let playerId: UUID
    let displayName: String
}

struct RealtimeGameSnapshot: Codable, Equatable, Sendable {
    let revision: Int
    let state: GameState
    let participants: [RealtimeParticipantBinding]
    let hostGamePlayerId: String
    let lastAppliedRequestId: UUID?

    init(
        revision: Int,
        state: GameState,
        participants: [RealtimeParticipantBinding],
        hostGamePlayerId: String,
        lastAppliedRequestId: UUID? = nil
    ) {
        self.revision = revision
        self.state = state
        self.participants = participants
        self.hostGamePlayerId = hostGamePlayerId
        self.lastAppliedRequestId = lastAppliedRequestId
    }

    func binding(forGamePlayerId id: String) -> RealtimeParticipantBinding? {
        participants.first(where: { $0.gamePlayerId == id })
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
    case start(RealtimeGameSnapshot)
    case action(RealtimeActionRequest)
    case snapshot(RealtimeGameSnapshot)
    case rejection(RealtimeActionRejection)
}

enum RealtimeMessageCodec {
    static let protocolVersion = 2

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
        guard binding.playerId == request.action.actorPlayerId else {
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
}
