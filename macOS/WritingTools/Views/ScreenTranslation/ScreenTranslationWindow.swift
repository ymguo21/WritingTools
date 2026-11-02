import SwiftUI

/// Window that shows the text recognized in a screenshot next to its translation.
class ScreenTranslationWindow: NSWindow {
    let viewModel: ScreenTranslationViewModel

    /// Shared frame name so all of these windows reopen at the same size/position.
    private static let sharedFrameName = "ScreenTranslationWindow"

    init(viewModel: ScreenTranslationViewModel) {
        self.viewModel = viewModel

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        self.title = viewModel.title
        self.minSize = NSSize(width: 420, height: 360)
        self.isReleasedWhenClosed = false
        self.contentViewController = NSHostingController(rootView: ScreenTranslationView(viewModel: viewModel))
        // Installing the content controller shrinks the window to the view's minimum size.
        self.setContentSize(NSSize(width: 600, height: 560))

        if !self.setFrameUsingName(Self.sharedFrameName) {
            self.center()
        }
    }

    override func close() {
        self.saveFrame(usingName: Self.sharedFrameName)
        viewModel.cancel()
        super.close()
        WindowManager.shared.removeScreenTranslationWindow(self)
    }
}
