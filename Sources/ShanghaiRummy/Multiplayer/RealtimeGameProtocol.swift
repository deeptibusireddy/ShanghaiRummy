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
    static let protocolVersion = 1

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
    private var buyWindowBaseRevision: Int?

    init(snapshot: RealtimeGameSnapshot) {
        self.snapshot = snapshot
        buyWindowBaseRevision = snapshot.state.phase == .awaitingDraw
            ? snapshot.revision
            : nil
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
        guard request.expectedRevision == snapshot.revision
                || (
                    request.expectedRevision < snapshot.revision
                    && canRebase(request)
                ) else {
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
            let next = RealtimeGameSnapshot(
                revision: snapshot.revision + 1,
                state: state,
                participants: snapshot.participants,
                hostGamePlayerId: snapshot.hostGamePlayerId,
                lastAppliedRequestId: request.id
            )
            if state.phase == .awaitingDraw {
                if snapshot.state.phase != .awaitingDraw {
                    buyWindowBaseRevision = next.revision
                }
            } else {
                buyWindowBaseRevision = nil
            }
            snapshot = next
            return .success(next)
        }
    }

    private func canRebase(_ request: RealtimeActionRequest) -> Bool {
        guard snapshot.state.phase == .awaitingDraw,
              let buyWindowBaseRevision,
              request.expectedRevision >= buyWindowBaseRevision else {
            return false
        }
        switch request.action {
        case .requestBuy, .cancelBuyRequest, .draw:
            return true
        default:
            return false
        }
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
