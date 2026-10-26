import SwiftUI

/// Window that shows a command's result as a reviewable word-level diff.
class ReviewWindow: NSWindow {
    let viewModel: ReviewViewModel

    /// Shared frame name so all review windows reopen at the same size/position.
    private static let sharedFrameName = "ReviewWindow"

    init(viewModel: ReviewViewModel) {
        self.viewModel = viewModel

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        self.title = viewModel.title
        self.minSize = NSSize(width: 640, height: 360)
        self.isReleasedWhenClosed = false
        self.contentViewController = NSHostingController(rootView: ReviewView(viewModel: viewModel))

        if !self.setFrameUsingName(Self.sharedFrameName) {
            self.center()
        }

        viewModel.onApplied = { [weak self] in
            self?.close()
        }
    }

    override func close() {
        self.saveFrame(usingName: Self.sharedFrameName)
        viewModel.cancel()
        super.close()
        WindowManager.shared.removeReviewWindow(self)
    }
}
