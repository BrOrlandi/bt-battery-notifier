import Foundation

/// Simple lookup: L("key")
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}

/// Format string lookup: L("key", arg1, arg2, ...)
func L(_ key: String, _ args: CVarArg...) -> String {
    String(format: NSLocalizedString(key, comment: ""), arguments: args)
}
