import AppKit
import SwiftUI

@MainActor
final class NetworkModel: ObservableObject {
    @Published private(set) var reading = NetworkReading.initial

    private let sampler = NetworkSampler()
    private var samplingTask: Task<Void, Never>?

    func start() {
        guard samplingTask == nil else { return }

        samplingTask = Task { [weak self] in
            guard let self else { return }

            while !Task.isCancelled {
                let now = ProcessInfo.processInfo.systemUptime
                reading = sampler.sample(now: now)

                NotificationCenter.default.post(
                    name: .init("NetSpeedModelDidChange"),
                    object: nil
                )

                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stop() {
        samplingTask?.cancel()
        samplingTask = nil
    }
}

@main
struct NetSpeedApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = NetworkModel()
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model.start()
        statusBarController = StatusBarController(model: model)
    }
}