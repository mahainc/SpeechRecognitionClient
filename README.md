# SpeechRecognitionClient

A TCA dependency client wrapping `SFSpeechRecognizer` for streaming speech-to-text. `startRecording()` returns an `AsyncStream<String>` of incremental transcripts; `stopRecording()` terminates the session and finishes the stream.

## Layout

- **`SpeechRecognitionClient`** — interface: `requestAuthorization()`, `startRecording() -> AsyncStream<String>`, `stopRecording()`, `isRecording`, plus an `AuthorizationStatus` enum unifying speech + microphone permission states.
- **`SpeechRecognitionClientLive`** — `SFSpeechRecognizer` + `AVAudioEngine` wrapper with a `final class RecognitionEngine: @unchecked Sendable` that owns the recognition task and bridges its delegate callbacks to the `AsyncStream` continuation.

## Installation

```swift
.package(url: "https://github.com/mahainc/SpeechRecognitionClient.git", from: "0.1.0"),
```

`SpeechRecognitionClient` on feature targets; `SpeechRecognitionClientLive` on the app target.

## Permissions

Both Speech Recognition and Microphone usage descriptions are required. In your `Info.plist`:

```xml
<key>NSSpeechRecognitionUsageDescription</key>
<string>Transcribe your voice into text.</string>
<key>NSMicrophoneUsageDescription</key>
<string>Capture audio for transcription.</string>
```

`requestAuthorization()` requests both permissions and returns the merged status — if either is denied, the result is `.denied`.

## Usage

```swift
import SpeechRecognitionClient
import ComposableArchitecture

@Reducer
struct VoiceInputFeature {
    @ObservableState
    struct State {
        var transcript: String = ""
        var isRecording: Bool = false
    }

    enum Action {
        case recordButtonTapped
        case authorizationResolved(AuthorizationStatus)
        case transcriptUpdated(String)
        case recordingFinished
    }

    @Dependency(\.speechRecognitionClient) var speech

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .recordButtonTapped where !state.isRecording:
                return .run { send in
                    let status = await speech.requestAuthorization()
                    await send(.authorizationResolved(status))
                }

            case .recordButtonTapped:
                return .run { send in
                    await speech.stopRecording()
                    await send(.recordingFinished)
                }

            case .authorizationResolved(.authorized):
                state.isRecording = true
                state.transcript = ""
                return .run { send in
                    for try await partial in try await speech.startRecording() {
                        await send(.transcriptUpdated(partial))
                    }
                    await send(.recordingFinished)
                }

            case .authorizationResolved:
                state.isRecording = false
                return .none

            case .transcriptUpdated(let text):
                state.transcript = text
                return .none

            case .recordingFinished:
                state.isRecording = false
                return .none
            }
        }
    }
}
```

## Testing

```swift
let store = TestStore(initialState: VoiceInputFeature.State()) {
    VoiceInputFeature()
} withDependencies: {
    $0.speechRecognitionClient.requestAuthorization = { .authorized }
    $0.speechRecognitionClient.startRecording = {
        AsyncStream { continuation in
            continuation.yield("hello world")
            continuation.finish()
        }
    }
}
```

## Dependencies

- `swift-composable-architecture` from 1.25.5

## Platform support

- iOS 17+
- macOS 14+ (compiles; `SFSpeechRecognizer` available on both, but mic + speech permission flows differ — verify on your target platform)

## License

MIT — see [LICENSE](./LICENSE).
