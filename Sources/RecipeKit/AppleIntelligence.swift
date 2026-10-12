import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Whether the on-device language model is ready, and a plain-language reason when it isn't.
public enum AppleIntelligence {
    public enum Status: Equatable, Sendable {
        case available
        case osTooOld
        case deviceNotEligible
        case notEnabled
        case modelNotReady
        case unknown

        public var isAvailable: Bool { self == .available }

        public var explanation: String {
            switch self {
            case .available: "Ready."
            case .osTooOld: "This needs iOS 26 or macOS 26."
            case .deviceNotEligible: "This device doesn't support Apple Intelligence."
            case .notEnabled: "Apple Intelligence is turned off. Turn it on in Settings under Apple Intelligence & Siri."
            case .modelNotReady: "Apple Intelligence is still downloading its language model. Try again in a few minutes."
            case .unknown: "Apple Intelligence isn't available right now."
            }
        }
    }

    public static var status: Status {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return .deviceNotEligible
                case .appleIntelligenceNotEnabled: return .notEnabled
                case .modelNotReady: return .modelNotReady
                @unknown default: return .unknown
                }
            }
        }
        #endif
        return .osTooOld
    }
}
