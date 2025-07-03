import ActivityKit
import Foundation

@available(iOS 16.2, *)
@objc public class LiveActivity: NSObject {
    private var activities: [String: Activity<GenericAttributes>] = [:]

    override public init() {
        super.init()
        Task {
            await rediscoverActivities()
            print("✅ Init complete. Active activities: \(activities.count)")
        }
    }
    
    private func rediscoverActivities() async {
        for activity in Activity<GenericAttributes>.activities {
            let id = activity.attributes.id

            switch activity.activityState {
            case .active, .stale:
                activities[id] = activity
                print("🔄 Rediscovered activity: \(id)")
            case .ended, .dismissed:
                // Remove from memory if it was there
                activities.removeValue(forKey: id)
                print("🧹 Ignored ended activity: \(id)")
            @unknown default:
                print("⚠️ Unknown state for activity: \(id)")
            }
        }
    }

    @objc public func isAvailable() -> Bool {
            return ActivityAuthorizationInfo().areActivitiesEnabled
    }

    @objc public func start(id: String, attributes: [String: String], content: [String: String])
        async throws
    {
            let attr = GenericAttributes(id: id, staticValues: attributes)
            let state = GenericAttributes.ContentState(values: content)
            let activity = try Activity<GenericAttributes>.request(
                attributes: attr, contentState: state, pushType: nil)
            activities[id] = activity
    }

    @objc public func update(id: String, content: [String: String]) async {
        // If activity not in memory, try to rediscover it from iOS
        if activities[id] == nil {
            await rediscoverActivities()
        }
        
        if let activity = activities[id] {
            let state = GenericAttributes.ContentState(values: content)
            await activity.update(ActivityContent(state: state, staleDate: nil))
        } else {
            print("❌ Failed to find activity for update: \(id)")
        }
    }

    @objc public func end(id: String, content: [String: String]) async {
        // If activity not in memory, try to rediscover it from iOS
        if activities[id] == nil {
            await rediscoverActivities()
        }
        
        if let activity = activities[id] {
            let state = GenericAttributes.ContentState(values: content)
            await activity.end(
                ActivityContent(state: state, staleDate: nil), dismissalPolicy: .default)
            activities.removeValue(forKey: id)
        } else {
            print("❌ Failed to find activity for end: \(id)")
        }
    }

    @objc public func isRunning(id: String) -> Bool {
        // If activity not in memory, try to rediscover it from iOS
        if activities[id] == nil {
            Task {
                await rediscoverActivities()
            }
        }
        
        return activities[id] != nil
    }

    @objc public func getCurrent(id: String?) -> [String: Any]? {
        var activity: Activity<GenericAttributes>?

        if let id = id {
            activity = activities[id]
        } else {
            activity = activities.values.first
        }

        guard let a = activity else { return nil }

        return [
            "id": a.id,
            "values": a.content.state.values,
            "isStale": a.content.staleDate != nil,
            "isEnded": a.activityState == .ended,
            "startedAt": a.content.state.values["startedAt"] ?? "",
        ]
    }
}
