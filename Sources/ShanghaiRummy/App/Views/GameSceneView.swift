import SwiftUI
import SpriteKit

/// SwiftUI wrapper for `GameScene`. Owns the scene instance and forwards
/// `GameViewModel` into it. Used by `GameContainerView`.
struct GameSceneView: View {
    @ObservedObject var vm: GameViewModel

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: makeScene(size: geo.size),
                       options: [.allowsTransparency])
                .ignoresSafeArea()
        }
    }

    private func makeScene(size: CGSize) -> SKScene {
        let scene = GameScene(size: size, viewModel: vm)
        scene.scaleMode = .resizeFill
        return scene
    }
}
