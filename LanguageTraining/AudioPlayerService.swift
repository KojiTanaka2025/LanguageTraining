import Foundation
import AVFoundation
import SwiftUI
import Combine

/// 音声再生を管理するサービス
@MainActor
final class AudioPlayerService: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var currentText: String?
    
    private var player: AVAudioPlayer?
    private var currentFileURL: URL?
    private var shouldDeleteAfterPlay = false
    
    static let shared = AudioPlayerService()
    
    private override init() {
        super.init()
    }
    
    /// 音声を再生する
    /// - Parameters:
    ///   - fileURL: 音声ファイルのURL
    ///   - text: 関連テキスト
    ///   - deleteAfterPlay: 再生後にファイルを削除するか（一時ファイルの場合はtrue）
    func play(fileURL: URL, text: String, deleteAfterPlay: Bool = false) throws {
        // 既存の再生を停止
        stop()
        
        currentFileURL = fileURL
        currentText = text
        self.shouldDeleteAfterPlay = deleteAfterPlay
        
        // AVAudioPlayerを初期化
        player = try AVAudioPlayer(contentsOf: fileURL)
        player?.delegate = self
        player?.prepareToPlay()

        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [])
        try session.setActive(true)
        #endif
        
        // 再生開始
        guard player?.play() == true else {
            throw AudioPlayerError.playbackFailed
        }
        
        isPlaying = true
    }
    
    /// 再生を停止
    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        currentText = nil
        
        // 一時ファイルの場合のみ削除
        if shouldDeleteAfterPlay, let url = currentFileURL {
            try? FileManager.default.removeItem(at: url)
        }
        currentFileURL = nil
        shouldDeleteAfterPlay = false
    }
    
    /// 一時停止
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    /// 再開
    func resume() {
        player?.play()
        isPlaying = true
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlayerService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stop()
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.stop()
        }
    }
}

// MARK: - Error

enum AudioPlayerError: Error, LocalizedError {
    case playbackFailed
    
    var errorDescription: String? {
        switch self {
        case .playbackFailed:
            return "Audio playback failed."
        }
    }
}
