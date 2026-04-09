import Dependencies
import DependenciesMacros
import Foundation

/// A dependency client for speech recognition (voice-to-text).
///
/// Usage in a reducer:
/// ```swift
/// @Dependency(\.speechRecognitionClient) var speechRecognitionClient
///
/// case .micButtonTapped:
///     return .run { [speechRecognitionClient] send in
///         let status = await speechRecognitionClient.requestAuthorization()
///         guard status == .authorized else { return }
///         let stream = try await speechRecognitionClient.startRecording()
///         for await transcription in stream {
///             await send(.voiceTranscriptionReceived(transcription))
///         }
///     }
/// ```
@DependencyClient
public struct SpeechRecognitionClient: Sendable {
    /// Request microphone and speech recognition authorization.
    public var requestAuthorization: @Sendable () async -> AuthorizationStatus = { .denied }

    /// Start recording and return a stream of live transcription updates.
    /// Each element is the latest best transcription (replaces previous, not appended).
    public var startRecording: @Sendable () async throws -> AsyncStream<String> = {
        AsyncStream { $0.finish() }
    }

    /// Stop the current recording session.
    public var stopRecording: @Sendable () async -> Void = {}

    /// Whether a recording session is currently active.
    public var isRecording: @Sendable () async -> Bool = { false }
}
