# Shanghai Rummy

An iOS multiplayer card game (Shanghai Rummy / Contract Rummy variant) built for
family play across iPhones via **Game Center**.

During TestFlight beta testing, two players can use **Quick Pair** at the same
time if Game Center cannot deliver a direct invitation.

> **Status:** Early scaffold. See [`docs/rules.md`](docs/rules.md) for the rule
> set being implemented and the session plan for milestones.

## Tech stack

| Layer          | Choice                                                        |
| -------------- | ------------------------------------------------------------- |
| Language       | Swift 5.9+                                                    |
| UI (menus)     | SwiftUI                                                       |
| Gameplay       | SpriteKit (card table, animations)                            |
| Multiplayer    | GameKit — live real-time matches via Game Center               |
| Persistence    | SwiftData (local), CloudKit (optional later)                  |
| Min iOS        | 17.0                                                          |
| Project gen    | [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`project.yml`) |

## Getting started (on macOS)

Prereqs: macOS with Xcode 15+, an Apple Developer account, and
[XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```sh
git clone https://github.com/deeptibusireddy/ShanghaiRummy.git
cd ShanghaiRummy
xcodegen generate      # regenerates ShanghaiRummy.xcodeproj from project.yml
open ShanghaiRummy.xcodeproj
```

Then in Xcode: select your Team under **Signing & Capabilities**, enable the
**Game Center** capability, and run on a simulator or device.

## Editing on Windows / Linux

You can edit sources, docs, and `project.yml` on any OS.

**No Mac?** Builds and tests run automatically on every push via GitHub Actions
(`.github/workflows/ios.yml`). Distribution to TestFlight is set up via Xcode
Cloud when the app is ready for beta testing. See
[`docs/deployment.md`](docs/deployment.md) for the full no-Mac workflow.

## Repo layout

```
Sources/ShanghaiRummy/    # App source
  App/                    # SwiftUI App entry, root view
  Models/                 # Card, Deck, Player, Meld, GameState
  Rules/                  # Round definitions, scoring, validation
  Multiplayer/            # GameKit matchmaking, host authority, live sync
  Scenes/                 # SpriteKit card table
  Views/                  # SwiftUI menus/lobby/score
  Resources/              # Assets, sounds
Tests/ShanghaiRummyTests/ # Unit tests (rules & scoring)
docs/                     # Rules & architecture notes
```

## License

TBD — likely MIT for now. See [`LICENSE`](LICENSE).
