import Dependencies
import SpeechRecognitionClient

#if os(iOS)
import AVFoundation
import Speech

extension SpeechRecognitionClient: DependencyKey {
    public static let liveValue: SpeechRecognitionClient = {
        let engine = RecognitionEngine()

        return SpeechRecognitionClient(
            requestAuthorization: {
                await engine.requestAuthorization()
            },
            startRecording: {
                try await engine.startRecording()
            },
            stopRecording: {
                engine.stopRecording()
            },
            isRecording: {
                engine.isRecording
            }
        )
    }()
}

private final class RecognitionEngine: @unchecked Sendable {
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let lock = NSLock()

    var isRecording: Bool {
        lock.withLock { audioEngine.isRunning }
    }

    func requestAuthorization() async -> AuthorizationStatus {
        // Request speech recognition permission
        let speechStatus = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status)
            }
        }

        guard speechStatus == .authorized else {
            return speechStatus.toAuthorizationStatus
        }

        // Request microphone permission
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { cont in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }

        return micGranted ? .authorized : .denied
    }

    func startRecording() async throws -> AsyncStream<String> {
        stopRecording()

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        lock.withLock { self.recognitionRequest = request }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        return AsyncStream { continuation in
            guard let recognizer = self.speechRecognizer, recognizer.isAvailable else {
                continuation.finish()
                return
            }

            let task = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    let transcription = result.bestTranscription.formattedString
                    continuation.yield(transcription)

                    if result.isFinal {
                        continuation.finish()
                    }
                }

                if error != nil {
                    continuation.finish()
                }
            }

            self.lock.withLock { self.recognitionTask = task }

            continuation.onTermination = { [weak self] _ in
                self?.lock.withLock { self?.recognitionTask?.cancel() }
            }
        }
    }

    func stopRecording() {
        lock.withLock {
            if audioEngine.isRunning {
                audioEngine.stop()
                audioEngine.inputNode.removeTap(onBus: 0)
            }
            recognitionRequest?.endAudio()
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

// MARK: - SFSpeechRecognizerAuthorizationStatus Mapping

extension SFSpeechRecognizerAuthorizationStatus {
    var toAuthorizationStatus: AuthorizationStatus {
        switch self {
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        case .authorized: .authorized
        @unknown default: .denied
        }
    }
}

#else

extension SpeechRecognitionClient: DependencyKey {
    public static let liveValue = SpeechRecognitionClient.noop
}

#endif
