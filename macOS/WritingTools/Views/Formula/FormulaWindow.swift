import SwiftUI

/// Window that shows a recognized formula next to its LaTeX source.
class FormulaWindow: NSWindow {
    let viewModel: FormulaViewModel

    /// Shared frame name so all formula windows reopen at the same size/position.
    private static let sharedFrameName = "FormulaWindow"

    init(viewModel: FormulaViewModel) {
        self.viewModel = viewModel

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        self.title = viewModel.title
        self.minSize = NSSize(width: 420, height: 360)
        self.isReleasedWhenClosed = false
        self.contentViewController = NSHostingController(rootView: FormulaView(viewModel: viewModel))
        // Installing the content controller shrinks the window to the view's minimum size.
        self.setContentSize(NSSize(width: 560, height: 520))

        if !self.setFrameUsingName(Self.sharedFrameName) {
            self.center()
        }
    }

    override func close() {
        self.saveFrame(usingName: Self.sharedFrameName)
        viewModel.cancel()
        super.close()
        WindowManager.shared.removeFormulaWindow(self)
    }
}
