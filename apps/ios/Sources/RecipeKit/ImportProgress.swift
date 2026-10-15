import Foundation

/// Progress an importer reports so the interface can show what it is doing.
public enum ImportEvent: Sendable {
    /// The titles of the steps this import will go through, in order.
    case plan([String])
    case began(Int)
    case finished(Int)
    /// The step turned out not to be needed.
    case skipped(Int)
}

public typealias ImportProgress = @Sendable (ImportEvent) -> Void
