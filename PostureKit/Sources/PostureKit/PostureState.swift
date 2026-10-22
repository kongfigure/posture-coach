/// The detector's current posture judgment.
public enum PostureState: Sendable, Equatable {
    case calibrating
    case upright
    case slouching
}
