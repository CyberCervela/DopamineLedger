// LinkedApp.swift
// Static catalog of apps supported by the digital gatekeeper feature.
// No SwiftData — pure value type, read-only at runtime.
//
// The catalog maps URL schemes (e.g. "youtube://") to display names,
// SF Symbol icons, and App Store URLs used in the "not installed" fallback.
// SessionView only needs the scheme + name stored on Activity; it consults
// this catalog only when it needs the App Store URL for the alert.

import Foundation

struct LinkedApp: Identifiable, Equatable {
    let id:          String  // URL scheme ("youtube://") or "custom" sentinel
    let name:        String
    let sfSymbol:    String
    // App Store page — opened if the app's URL scheme doesn't resolve on device.
    let appStoreURL: String

    static let catalog: [LinkedApp] = [
        LinkedApp(id: "youtube://",      name: "YouTube",    sfSymbol: "play.rectangle.fill", appStoreURL: "https://apps.apple.com/app/id544007664"),
        LinkedApp(id: "twitter://",      name: "Twitter / X",sfSymbol: "bubble.left.fill",    appStoreURL: "https://apps.apple.com/app/id333903271"),
        LinkedApp(id: "instagram://",    name: "Instagram",  sfSymbol: "camera.circle.fill",  appStoreURL: "https://apps.apple.com/app/id389801252"),
        LinkedApp(id: "snapchat://",     name: "Snapchat",   sfSymbol: "camera.fill",         appStoreURL: "https://apps.apple.com/app/id447188370"),
        LinkedApp(id: "fb://",           name: "Facebook",   sfSymbol: "person.2.fill",       appStoreURL: "https://apps.apple.com/app/id284882215"),
        LinkedApp(id: "tiktok://",       name: "TikTok",     sfSymbol: "music.note",          appStoreURL: "https://apps.apple.com/app/id835599320"),
        LinkedApp(id: "nflx://",         name: "Netflix",    sfSymbol: "film.fill",           appStoreURL: "https://apps.apple.com/app/id363590051"),
        LinkedApp(id: "googlechrome://", name: "Chrome",     sfSymbol: "globe",               appStoreURL: "https://apps.apple.com/app/id535886823"),
    ]
}
