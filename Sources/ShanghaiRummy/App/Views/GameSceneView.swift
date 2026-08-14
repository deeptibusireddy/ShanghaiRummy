import SwiftUI
import SpriteKit
import UIKit

/// SwiftUI wrapper for `GameScene`. Owns the scene instance and forwards
/// `GameViewModel` into it. Used by `GameContainerView`.
struct GameSceneView: View {
    let vm: GameViewModel
    let theme: VisualTheme
    @State private var scene: GameScene

    init(vm: GameViewModel, theme: VisualTheme = .gameNight) {
        self.vm = vm
        self.theme = theme
        _scene = State(initialValue: GameScene(
            size: CGSize(width: 1, height: 1),
            viewModel: vm,
            theme: theme
        ))
    }

    var body: some View {
        GeometryReader { geo in
            SpriteView(scene: scene,
                       options: [.allowsTransparency])
                .ignoresSafeArea()
                .onAppear {
                    updateSceneLayout(using: geo)
                }
                .onChange(of: geo.size) { _, _ in
                    updateSceneLayout(using: geo)
                }
                .onChange(of: geo.safeAreaInsets) { _, _ in
                    updateSceneLayout(using: geo)
                }
        }
    }

    private func updateSceneLayout(using geometry: GeometryProxy) {
        let safeArea = geometry.safeAreaInsets
        scene.updateLayout(
            size: geometry.size,
            safeAreaInsets: UIEdgeInsets(
                top: safeArea.top,
                left: safeArea.leading,
                bottom: safeArea.bottom,
                right: safeArea.trailing
            )
        )
    }
}
