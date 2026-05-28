//
//  Colors.swift
//  StudyPlanner
//

import SwiftUI

// MARK: - Indigo values (avoids repeating literals everywhere)
private let indigoR: Double = 0.310
private let indigoG: Double = 0.275
private let indigoB: Double = 0.898

extension Color {

    // MARK: - Accent
    /// Primary indigo accent. Named `appAccent` to avoid shadowing
    /// SwiftUI's built-in `.accent` environment color.
    static let appAccent    = Color(red: indigoR, green: indigoG, blue: indigoB)
    static let appAccentSoft = Color(red: indigoR, green: indigoG, blue: indigoB).opacity(0.10)

    // MARK: - Progress ring
    static let examGreen = Color(red: 0.133, green: 0.773, blue: 0.408)

    // MARK: - Surfaces
    static let cardSurface   = Color(.secondarySystemBackground)
    static let dividerColor  = Color(.separator).opacity(0.5)

    // MARK: - Calendar palette
    static let eventIndigoBG   = Color(red: 0.918, green: 0.914, blue: 0.988)
    static let eventIndigoLine = Color(red: indigoR, green: indigoG, blue: indigoB)

    static let eventTealBG     = Color(red: 0.878, green: 0.965, blue: 0.953)
    static let eventTealLine   = Color(red: 0.059, green: 0.671, blue: 0.561)

    static let eventRoseBG     = Color(red: 0.996, green: 0.898, blue: 0.914)
    static let eventRoseLine   = Color(red: 0.882, green: 0.180, blue: 0.361)
}

// MARK: - Event palette cycling
enum EventPalette {
    case indigo, teal, rose

    static func forIndex(_ i: Int) -> EventPalette {
        switch i % 3 {
        case 0:  return .indigo
        case 1:  return .teal
        default: return .rose
        }
    }

    var background: Color {
        switch self {
        case .indigo: return .eventIndigoBG
        case .teal:   return .eventTealBG
        case .rose:   return .eventRoseBG
        }
    }

    var accent: Color {
        switch self {
        case .indigo: return .eventIndigoLine
        case .teal:   return .eventTealLine
        case .rose:   return .eventRoseLine
        }
    }
}
