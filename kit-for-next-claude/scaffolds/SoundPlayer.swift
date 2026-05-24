// SoundPlayer.swift
// FRESH for round 2 — not transplanted (round 1 had no sound layer).
//
// Stub. Round 2 should fill this in when the first SemanticSound is
// actually wired up at a call site. Until then: this file exists as
// the planned shape, with TODOs.
//
// Why a service: the active theme answers `theme.sound(.questDone)`
// with a `SoundAsset?`. Some other piece has to actually *play* that
// asset. Doing it inline in views is messy (AVAudioPlayer lifecycle,
// session category, mixing with other audio). This service owns that.

import Foundation
import AVFoundation

@MainActor
enum SoundPlayer {

    // Cache of resolved players so we don't re-decode on every play.
    // Keyed by "<resourceName>.<extension>".
    private static var cache: [String: AVAudioPlayer] = [:]

    // Play a themed sound. No-op for nil (which is how SystemTheme
    // returns "silence" for most roles).
    static func play(_ asset: SoundAsset?) {
        guard let asset else { return }

        // TODO: respect a Settings master volume / mute toggle. Round 2
        //       should add one before sound effects feel intrusive.
        let key = "\(asset.resourceName).\(asset.fileExtension)"

        if let cached = cache[key] {
            cached.volume = asset.volume
            cached.currentTime = 0
            cached.play()
            return
        }

        guard let url = Bundle.main.url(
            forResource: asset.resourceName,
            withExtension: asset.fileExtension
        ) else {
            // The asset is missing from the bundle. Silently fail in
            // release; print in debug so we notice during development.
            #if DEBUG
            print("[SoundPlayer] missing asset:", key)
            #endif
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.volume = asset.volume
            player.prepareToPlay()
            cache[key] = player
            player.play()
        } catch {
            #if DEBUG
            print("[SoundPlayer] failed to load:", key, error)
            #endif
        }
    }

    // TODO: set up an AVAudioSession category at app launch so our
    //       sounds duck (or mix nicely with) the user's music. Default
    //       behavior interrupts playing music, which is rude for a
    //       low-stakes "you finished a quest" sound.
    static func configureAudioSession() {
        // intentionally unimplemented — fill in when first needed
    }
}
