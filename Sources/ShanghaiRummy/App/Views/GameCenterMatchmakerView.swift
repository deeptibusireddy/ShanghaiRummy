import GameKit
import SwiftUI
import UIKit

struct GameCenterMatchmakerView: UIViewControllerRepresentable {
    @ObservedObject var manager: GameCenterManager

    func makeUIViewController(context: Context) -> UIViewController {
        if let controller = manager.makeMatchmakerViewController() {
            return controller
        }

        let controller = UIViewController()
        controller.view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Game Center matchmaking is unavailable."
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
                equalTo: controller.view.leadingAnchor,
                constant: 24
            ),
            label.trailingAnchor.constraint(
                equalTo: controller.view.trailingAnchor,
                constant: -24
            ),
            label.centerYAnchor.constraint(equalTo: controller.view.centerYAnchor),
        ])
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {}
}

struct GameCenterAuthenticationView: UIViewControllerRepresentable {
    let viewController: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        viewController
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {}
}
