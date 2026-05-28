// IconResolver.swift
// FRESH for round 2 — not transplanted.
//
// Implementation detail of `theme.icon(_:)`. Each theme calls into one
// of the two lookup tables here. Keeping both tables in this single
// file makes it trivial to compare the two visual languages at a
// glance — when you add a new SemanticIcon, you write two entries here
// and it's done.
//
// Why a theme-bound resolver matters:
//   In round 1, IconResolver returned SF Symbols for everyone. When
//   PixelArt was added, views still called Image(systemName:) directly
//   in places — the resolver wasn't on the hot path. Round 2 makes the
//   resolver the ONLY way an icon ever enters a view, by going through
//   `theme.icon(.charger)` etc. The active theme decides which table
//   below to read.
//
// Example divergence — `.charger`:
//   - SystemTheme.icon(.charger)
//       → Image(systemName: "bolt.fill")               // an SF Symbol
//   - PixelArtTheme.icon(.charger)
//       → Image("pixel.charger")                       // a 32×32 PNG
//                                                        from the asset
//                                                        catalog
//   Same semantic role. Two completely different renderings. Zero
//   change required in the view that used it.

import SwiftUI

enum IconResolver {

    // MARK: User-chosen activity icons
    //
    // A flat curated list of SF Symbol names the user can assign to an activity.
    // Keeping it flat (no tags, no kind-filtering) — that was the backlog note.
    // The rule "Never call Image(systemName:) outside IconResolver" is satisfied
    // because views call activityIconImage(named:), not Image(systemName:) directly.

    static let activityIcons: [String] = [
        // study / mind
        "book.fill", "graduationcap.fill", "brain.head.profile", "pencil", "doc.fill",
        // health / body
        "figure.walk", "figure.run", "heart.fill", "dumbbell.fill", "bed.double.fill",
        // leisure
        "gamecontroller.fill", "tv.fill", "music.note", "film.fill", "headphones",
        // food / home
        "fork.knife", "cup.and.saucer.fill", "house.fill", "leaf.fill", "cart.fill",
        // work / comms
        "briefcase.fill", "laptopcomputer", "phone.fill", "message.fill",
        // misc
        "star.fill", "bolt.fill", "hourglass", "moon.fill", "sun.max.fill", "drop.fill", "clock.fill"
    ]

    static func activityIconImage(named symbol: String) -> Image {
        Image(systemName: symbol)
    }

    // MARK: SystemTheme mapping (semantic → SF Symbol name)

    static func systemSymbolName(for icon: SemanticIcon) -> String {
        switch icon {
        // activity kinds
        case .charger:  return "bolt.fill"
        case .spender:  return "hourglass"
        case .quest:    return "checkmark.seal.fill"

        // navigation
        case .home:     return "house"
        case .stats:    return "chart.bar"
        case .forward:  return "chevron.right"

        // chrome
        case .add:      return "plus"
        case .edit:     return "pencil"
        case .delete:   return "trash"
        case .settings: return "gearshape"
        case .back:     return "chevron.left"
        case .close:    return "xmark"
        case .info:     return "info.circle"

        // economy
        case .balance:  return "creditcard"
        case .debt:     return "exclamationmark.triangle.fill"
        case .repay:    return "arrow.uturn.left.circle.fill"

        // session
        case .play:     return "play.fill"
        case .stop:     return "stop.fill"
        case .timer:    return "timer"
        case .bell:     return "bell.fill"
        }
    }

    // MARK: PixelArtTheme mapping (semantic → asset-catalog image name)
    //
    // Convention: every pixel-art icon ships in the asset catalog as
    // `pixel.<role>` (e.g. `pixel.charger.imageset`). If the asset is
    // missing, SwiftUI renders an empty Image gracefully — but the
    // user will see a blank space, so add the asset before merging the
    // role.

    static func pixelArtImage(for icon: SemanticIcon) -> Image {
        Image(pixelArtAssetName(for: icon))
            .renderingMode(.original)
            .interpolation(.none)        // keeps pixel art crisp
    }

    static func pixelArtAssetName(for icon: SemanticIcon) -> String {
        switch icon {
        case .charger:  return "pixel.charger"
        case .spender:  return "pixel.spender"
        case .quest:    return "pixel.quest"

        case .home:     return "pixel.home"
        case .stats:    return "pixel.stats"
        case .forward:  return "pixel.forward"

        case .add:      return "pixel.add"
        case .edit:     return "pixel.edit"
        case .delete:   return "pixel.delete"
        case .settings: return "pixel.settings"
        case .back:     return "pixel.back"
        case .close:    return "pixel.close"
        case .info:     return "pixel.info"

        case .balance:  return "pixel.balance"
        case .debt:     return "pixel.debt"
        case .repay:    return "pixel.repay"

        case .play:     return "pixel.play"
        case .stop:     return "pixel.stop"
        case .timer:    return "pixel.timer"
        case .bell:     return "pixel.bell"
        }
    }
}
