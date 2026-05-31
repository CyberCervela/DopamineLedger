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
        // Streaming
        LinkedApp(id: "youtube://",      name: "YouTube",      sfSymbol: "play.rectangle.fill",              appStoreURL: "https://apps.apple.com/app/id544007664"),
        LinkedApp(id: "nflx://",         name: "Netflix",      sfSymbol: "film.fill",                        appStoreURL: "https://apps.apple.com/app/id363590051"),
        LinkedApp(id: "disneyplus://",   name: "Disney+",      sfSymbol: "wand.and.stars",                   appStoreURL: "https://apps.apple.com/app/id1446075923"),
        LinkedApp(id: "aiv://",          name: "Prime Video",  sfSymbol: "play.square.fill",                 appStoreURL: "https://apps.apple.com/app/id545519333"),
        LinkedApp(id: "hulu://",         name: "Hulu",         sfSymbol: "play.circle.fill",                 appStoreURL: "https://apps.apple.com/app/id376510438"),
        LinkedApp(id: "max://",          name: "Max",          sfSymbol: "play.tv.fill",                     appStoreURL: "https://apps.apple.com/app/id695003446"),
        LinkedApp(id: "twitch://",       name: "Twitch",       sfSymbol: "dot.radiowaves.right",             appStoreURL: "https://apps.apple.com/app/id460177396"),
        // Social
        LinkedApp(id: "instagram://",    name: "Instagram",    sfSymbol: "camera.circle.fill",               appStoreURL: "https://apps.apple.com/app/id389801252"),
        LinkedApp(id: "tiktok://",       name: "TikTok",       sfSymbol: "music.note",                       appStoreURL: "https://apps.apple.com/app/id835599320"),
        LinkedApp(id: "threads://",      name: "Threads",      sfSymbol: "bubble.left.and.bubble.right.fill", appStoreURL: "https://apps.apple.com/app/id6446901002"),
        LinkedApp(id: "reddit://",       name: "Reddit",       sfSymbol: "arrow.up.square.fill",             appStoreURL: "https://apps.apple.com/app/id1064216828"),
        LinkedApp(id: "twitter://",      name: "Twitter / X",  sfSymbol: "bubble.left.fill",                 appStoreURL: "https://apps.apple.com/app/id333903271"),
        LinkedApp(id: "fb://",           name: "Facebook",     sfSymbol: "person.2.fill",                    appStoreURL: "https://apps.apple.com/app/id284882215"),
        LinkedApp(id: "pinterest://",    name: "Pinterest",    sfSymbol: "pin.fill",                         appStoreURL: "https://apps.apple.com/app/id429047995"),
        LinkedApp(id: "linkedin://",     name: "LinkedIn",     sfSymbol: "briefcase.fill",                   appStoreURL: "https://apps.apple.com/app/id288429040"),
        LinkedApp(id: "snapchat://",     name: "Snapchat",     sfSymbol: "camera.fill",                      appStoreURL: "https://apps.apple.com/app/id447188370"),
        LinkedApp(id: "bereal://",       name: "BeReal",       sfSymbol: "livephoto",                        appStoreURL: "https://apps.apple.com/app/id1459645446"),
        // Gaming
        LinkedApp(id: "roblox://",       name: "Roblox",       sfSymbol: "gamecontroller.fill",              appStoreURL: "https://apps.apple.com/app/id431946152"),
        // Productivity & Learning (charger-side)
        LinkedApp(id: "duolingo://",     name: "Duolingo",     sfSymbol: "translate",                        appStoreURL: "https://apps.apple.com/app/id570060128"),
        LinkedApp(id: "kindle://",       name: "Kindle",       sfSymbol: "book.closed.fill",                 appStoreURL: "https://apps.apple.com/app/id302584613"),
        LinkedApp(id: "headspace://",    name: "Headspace",    sfSymbol: "brain.head.profile",               appStoreURL: "https://apps.apple.com/app/id493145008"),
        LinkedApp(id: "calm://",         name: "Calm",         sfSymbol: "moon.stars.fill",                  appStoreURL: "https://apps.apple.com/app/id571800810"),
        LinkedApp(id: "forest://",       name: "Forest",       sfSymbol: "tree.fill",                        appStoreURL: "https://apps.apple.com/app/id866450515"),
        LinkedApp(id: "notion://",       name: "Notion",       sfSymbol: "note.text",                        appStoreURL: "https://apps.apple.com/app/id1232780281"),
        // Browser
        LinkedApp(id: "googlechrome://", name: "Chrome",       sfSymbol: "globe",                            appStoreURL: "https://apps.apple.com/app/id535886823"),
    ]
}
