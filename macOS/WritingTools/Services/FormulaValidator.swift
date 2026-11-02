import Foundation
import SwiftMath

/// Checks a formula with the same parser the preview renders with.
enum FormulaValidator {
    /// Returns the parser's error message, or nil when the formula can be rendered.
    static func error(for latex: String) -> String? {
        var error: NSError?
        let list = MTMathListBuilder.build(fromString: latex, error: &error)
        if let error { return error.localizedDescription }
        return list == nil ? "Invalid LaTeX" : nil
    }
}
