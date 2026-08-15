#if os(macOS)
import AppKit
import SwiftUI

enum LayoutPersistence {
    static let windowFrameKey = "LanguageTraining.window.frame"
    static let explainSplitKey = "LanguageTraining.split.explain"
    static let librarySplitKey = "LanguageTraining.split.library"

    static func saveNow() {
        WindowFrameController.shared.saveAttachedWindows()
        SplitLayoutController.shared.saveAll()
    }
}

struct WindowFramePersistence: NSViewRepresentable {
    func makeNSView(context: Context) -> WindowProbeView {
        WindowProbeView()
    }

    func updateNSView(_ nsView: WindowProbeView, context: Context) {}
}

final class WindowProbeView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window {
            WindowFrameController.shared.attach(window)
        }
    }
}

final class WindowFrameController {
    static let shared = WindowFrameController()

    private var observers: [ObjectIdentifier: [NSObjectProtocol]] = [:]
    private var restorePasses: [ObjectIdentifier: Int] = [:]
    private var attached = NSHashTable<NSWindow>.weakObjects()

    func attach(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        attached.add(window)
        restore(window)

        guard observers[id] == nil else { return }

        let center = NotificationCenter.default
        var tokens: [NSObjectProtocol] = []
        tokens.append(center.addObserver(forName: NSWindow.didMoveNotification, object: window, queue: .main) { [weak self] _ in
            self?.save(window)
        })
        tokens.append(center.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main) { [weak self] _ in
            self?.save(window)
        })
        tokens.append(center.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { [weak self] _ in
            self?.save(window)
        })
        observers[id] = tokens

        // SwiftUI applies defaultSize after the first layout; re-apply a few times at launch.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.restore(window) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.restore(window) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in self?.restore(window) }
    }

    func saveAttachedWindows() {
        for window in attached.allObjects {
            save(window)
        }
    }

    private func restore(_ window: NSWindow) {
        let id = ObjectIdentifier(window)
        let pass = restorePasses[id] ?? 0
        guard pass < 6 else { return }
        restorePasses[id] = pass + 1

        guard let raw = UserDefaults.standard.string(forKey: LayoutPersistence.windowFrameKey) else { return }
        var frame = NSRectFromString(raw)
        guard frame.width >= 400, frame.height >= 300, frame.width.isFinite, frame.height.isFinite else { return }
        frame.size.width = max(frame.width, 980)
        frame.size.height = max(frame.height, 640)
        frame = clamp(frame, for: window)
        if !approximatelyEqual(window.frame, frame) {
            window.setFrame(frame, display: true)
        }
    }

    private func save(_ window: NSWindow) {
        let frame = window.frame
        guard frame.width >= 400, frame.height >= 300 else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: LayoutPersistence.windowFrameKey)
    }

    private func clamp(_ frame: NSRect, for window: NSWindow) -> NSRect {
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen else { return frame }
        return window.constrainFrameRect(frame, to: screen)
    }

    private func approximatelyEqual(_ a: NSRect, _ b: NSRect) -> Bool {
        abs(a.origin.x - b.origin.x) < 1
            && abs(a.origin.y - b.origin.y) < 1
            && abs(a.width - b.width) < 1
            && abs(a.height - b.height) < 1
    }
}

struct SplitViewPersistence: NSViewRepresentable {
    let key: String

    func makeNSView(context: Context) -> SplitProbeView {
        let view = SplitProbeView()
        view.key = key
        return view
    }

    func updateNSView(_ nsView: SplitProbeView, context: Context) {
        nsView.key = key
    }
}

final class SplitProbeView: NSView {
    var key: String = ""

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil, !key.isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            SplitLayoutController.shared.attach(from: self, key: self.key)
        }
    }
}

final class SplitLayoutController {
    static let shared = SplitLayoutController()

    private struct Record {
        var key: String
        var observer: NSObjectProtocol
        var restoringUntil: Date
    }

    private var records: [ObjectIdentifier: Record] = [:]
    private var tracked = NSHashTable<NSSplitView>.weakObjects()

    func attach(from view: NSView, key: String, attempt: Int = 0) {
        guard let split = findSplitView(from: view) else {
            guard attempt < 40 else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak view] in
                guard let view else { return }
                self.attach(from: view, key: key, attempt: attempt + 1)
            }
            return
        }

        let id = ObjectIdentifier(split)
        tracked.add(split)
        restore(split, key: key)

        if records[id] == nil {
            let observer = NotificationCenter.default.addObserver(
                forName: NSSplitView.didResizeSubviewsNotification,
                object: split,
                queue: .main
            ) { [weak self] _ in
                self?.saveIfUserDriven(split, key: key)
            }
            records[id] = Record(key: key, observer: observer, restoringUntil: Date().addingTimeInterval(0.6))
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { self.restore(split, key: key) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.restore(split, key: key) }
        }
    }

    func saveAll() {
        for split in tracked.allObjects {
            let id = ObjectIdentifier(split)
            guard let key = records[id]?.key else { continue }
            save(split, key: key)
        }
    }

    private func restore(_ split: NSSplitView, key: String) {
        let id = ObjectIdentifier(split)
        if var record = records[id] {
            record.restoringUntil = Date().addingTimeInterval(0.4)
            records[id] = record
        }

        guard let fractions = UserDefaults.standard.array(forKey: key) as? [Double],
              fractions.count == split.subviews.count,
              fractions.allSatisfy({ $0 > 0 && $0.isFinite }) else { return }

        let dividerTotal = split.dividerThickness * CGFloat(max(split.subviews.count - 1, 0))
        let span = (split.isVertical ? split.bounds.width : split.bounds.height) - dividerTotal
        guard span > 1 else { return }

        var position: CGFloat = 0
        for index in 0..<(fractions.count - 1) {
            position += CGFloat(fractions[index]) * span
            split.setPosition(position, ofDividerAt: index)
            position += split.dividerThickness
        }
    }

    private func saveIfUserDriven(_ split: NSSplitView, key: String) {
        let id = ObjectIdentifier(split)
        if let until = records[id]?.restoringUntil, Date() < until {
            return
        }
        if split.window?.inLiveResize == true {
            save(split, key: key)
            return
        }
        switch NSApp.currentEvent?.type {
        case .leftMouseDragged, .leftMouseUp, .leftMouseDown:
            save(split, key: key)
        default:
            break
        }
    }

    private func save(_ split: NSSplitView, key: String) {
        let sizes = split.subviews.map { split.isVertical ? $0.frame.width : $0.frame.height }
        let total = sizes.reduce(0, +)
        guard total > 1, sizes.count >= 2 else { return }
        let fractions = sizes.map { Double($0 / total) }
        UserDefaults.standard.set(fractions, forKey: key)
    }

    private func findSplitView(from view: NSView) -> NSSplitView? {
        var current: NSView? = view
        while let node = current {
            if let split = node as? NSSplitView {
                return split
            }
            current = node.superview
        }
        return nil
    }
}
#endif
