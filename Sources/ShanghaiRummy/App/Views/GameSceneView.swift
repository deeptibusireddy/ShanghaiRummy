import SwiftUI
import SpriteKit

/// SwiftUI wrapper for `GameScene`. Owns the scene instance and forwards
/// `GameViewModel` into it. Used by `GameContainerView`.
struct GameSceneView: View {
    @ObservedObject var vm: GameViewModel
    let theme: VisualTheme

    init(vm: GameViewModel, theme: VisualTheme = .cozyWood) {
        self.vm = vm
        self.theme = theme
    }

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: makeScene(size: geo.size),
                       options: [.allowsTransparency])
                .ignoresSafeArea()
        }
    }

    private func makeScene(size: CGSize) -> SKScene {
        let scene = GameScene(size: size, viewModel: vm, theme: theme)
        scene.scaleMode = .resizeFill
        return scene
    }
}
