import SwiftUI

/// 书籍主题(纸感优先,亮色暖纸白为默认 —— 营销与阅读一致)
enum FolioTheme: String, CaseIterable, Identifiable, Codable {
    case paper, sepia, dark
    var id: String { rawValue }

    var bg: String {
        switch self {
        case .paper: return "#FBF8F1"
        case .sepia: return "#F3E7CF"
        case .dark:  return "#141311"
        }
    }
    var fg: String {
        switch self {
        case .paper: return "#26221C"
        case .sepia: return "#4A3B26"
        case .dark:  return "#D8D2C4"
        }
    }
    var dim: String {
        switch self {
        case .paper: return "#9A9081"
        case .sepia: return "#A08A64"
        case .dark:  return "#8A8375"
        }
    }
    /// SwiftUI 侧展示用
    var color: Color {
        switch self {
        case .paper: return Color(red: 0.984, green: 0.973, blue: 0.945)
        case .sepia: return Color(red: 0.953, green: 0.906, blue: 0.812)
        case .dark:  return Color(red: 0.078, green: 0.075, blue: 0.067)
        }
    }
    var icon: String {
        switch self {
        case .paper: return "sun.max"
        case .sepia: return "lamp.desk"
        case .dark:  return "moon"
        }
    }
    var label: String {
        switch self {
        case .paper: return "纸白"
        case .sepia: return "羊皮"
        case .dark:  return "夜间"
        }
    }
}
