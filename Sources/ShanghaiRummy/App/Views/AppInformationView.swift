import Foundation
import SwiftUI

enum AppInformationLinks {
    static let privacyPolicy = URL(
        string: "https://github.com/deeptibusireddy/ShanghaiRummy/"
            + "blob/main/docs/app-store/privacy-policy.md"
    )!
    static let support = URL(
        string: "https://github.com/deeptibusireddy/ShanghaiRummy/"
            + "blob/main/docs/app-store/support.md"
    )!
    static let applePrivacy = URL(
        string: "https://www.apple.com/legal/privacy/"
    )!
}

struct AppInformationView: View {
    @Environment(\.dismiss) private var dismiss
    private let palette = EntryFinalistPalette.bundAfterDark

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    palette.background,
                    palette.backgroundSecondary,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    HStack(alignment: .top, spacing: 22) {
                        informationCard(
                            eyebrow: "YOUR PRIVACY",
                            title: "The table stays private.",
                            symbol: "hand.raised.fill"
                        ) {
                            Text(
                                "Solo saves and preferences remain on this "
                                    + "iPad. We do not operate a server, run "
                                    + "analytics, show ads, or sell personal "
                                    + "information."
                            )

                            Text(
                                "Live tables use Apple Game Center to carry "
                                    + "player identity and gameplay messages. "
                                    + "We do not retain that information on "
                                    + "developer-operated systems."
                            )

                            informationLink(
                                title: "Read the Privacy Policy",
                                symbol: "doc.text.fill",
                                destination:
                                    AppInformationLinks.privacyPolicy,
                                identifier: "privacy-policy-link"
                            )

                            informationLink(
                                title: "Apple Privacy Policy",
                                symbol: "apple.logo",
                                destination:
                                    AppInformationLinks.applePrivacy,
                                identifier: "apple-privacy-link"
                            )
                        }

                        informationCard(
                            eyebrow: "NEED A HAND?",
                            title: "Support between rounds.",
                            symbol: "questionmark.circle.fill"
                        ) {
                            Text(
                                "Find help with Game Center invitations, "
                                    + "saved solo games, turn sounds, and "
                                    + "common table setup questions."
                            )

                            informationLink(
                                title: "Open Support",
                                symbol: "lifepreserver.fill",
                                destination: AppInformationLinks.support,
                                identifier: "support-link"
                            )

                            Divider()
                                .overlay(palette.muted.opacity(0.35))

                            Text("ABOUT THIS BUILD")
                                .font(.caption.weight(.black))
                                .tracking(2)
                                .foregroundStyle(palette.gold)

                            Text(versionText)
                                .font(.headline.weight(.bold))
                                .foregroundStyle(palette.text)
                        }
                    }
                }
                .padding(.horizontal, 44)
                .padding(.vertical, 34)
            }
        }
        .accessibilityIdentifier("privacy-support-view")
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Text("PRIVACY & SUPPORT")
                    .font(.caption.weight(.black))
                    .tracking(3.2)
                    .foregroundStyle(palette.gold)

                Text("Shanghai Rummy Nights")
                    .font(.system(
                        size: 35,
                        weight: .black,
                        design: .rounded
                    ))
                    .foregroundStyle(palette.text)
            }

            Spacer()

            Button("Done") {
                dismiss()
            }
            .buttonStyle(EntrySecondaryButtonStyle(
                foreground: palette.text,
                stroke: palette.muted
            ))
            .accessibilityIdentifier("close-privacy-support")
        }
    }

    private func informationCard<Content: View>(
        eyebrow: String,
        title: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(palette.accent)

            Text(eyebrow)
                .font(.caption.weight(.black))
                .tracking(2.2)
                .foregroundStyle(palette.gold)

            Text(title)
                .font(.title2.weight(.black))
                .foregroundStyle(palette.text)

            content()
                .font(.body.weight(.medium))
                .foregroundStyle(palette.muted)
                .lineSpacing(4)

            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 390, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22)
                .fill(palette.panelStrong.opacity(0.94))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(palette.gold.opacity(0.28), lineWidth: 1)
        }
    }

    private func informationLink(
        title: String,
        symbol: String,
        destination: URL,
        identifier: String
    ) -> some View {
        Link(destination: destination) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .frame(width: 24)

                Text(title)
                    .font(.headline.weight(.bold))

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.black))
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, 16)
            .frame(minHeight: 50)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(palette.background.opacity(0.38))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(palette.muted.opacity(0.4), lineWidth: 1)
            }
        }
        .accessibilityIdentifier(identifier)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String
            ?? "Unknown"
        let build = info?["CFBundleVersion"] as? String ?? "Unknown"
        return "Version \(version) (\(build))"
    }
}

