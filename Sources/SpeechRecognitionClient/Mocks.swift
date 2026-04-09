import Dependencies

extension SpeechRecognitionClient: TestDependencyKey {
    /// Test value — unimplemented, fails if called without explicit override.
    public static let testValue = SpeechRecognitionClient()

    /// Preview value — silent no-op, speech recognition doesn't fire in previews.
    public static let previewValue = SpeechRecognitionClient.noop
}

extension SpeechRecognitionClient {
    /// A no-op client that silently ignores all speech recognition requests.
    public static let noop = SpeechRecognitionClient(
        requestAuthorization: { .denied },
        startRecording: { AsyncStream { $0.finish() } },
        stopRecording: {},
        isRecording: { false }
    )
}

extension DependencyValues {
    public var speechRecognitionClient: SpeechRecognitionClient {
        get { self[SpeechRecognitionClient.self] }
        set { self[SpeechRecognitionClient.self] = newValue }
    }
}
