import Foundation

/// Type of schemes that are generated by `SchemesGenerator`
public enum SchemeGeneration: String {
    public static var `default`: SchemeGeneration { .defaultAndCustom }
    
    /// Generate default schemes with custom schemes if any
    case defaultAndCustom
    /// Generate only custom schemes
    case customOnly
}
