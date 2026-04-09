import Foundation

/// Authorization status for speech recognition and microphone access.
public enum AuthorizationStatus: Sendable, Equatable {
    case notDetermined
    case denied
    case restricted
    case authorized
}
