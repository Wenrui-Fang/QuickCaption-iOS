//
//  SubtitleStylePreset.swift
//  QuickCaption
//
//  Created by Codex on 5/30/26.
//

import CoreGraphics
import SwiftUI

enum SubtitleStylePreset: String, CaseIterable, Identifiable {
    case classic
    case clean
    case creator

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic:
            "Classic"
        case .clean:
            "Clean"
        case .creator:
            "Creator"
        }
    }

    var fontWeight: Font.Weight {
        switch self {
        case .classic:
            .semibold
        case .clean, .creator:
            .bold
        }
    }

    nonisolated var relativeFontScale: CGFloat {
        switch self {
        case .classic:
            0.052
        case .clean:
            0.056
        case .creator:
            0.062
        }
    }

    var textColor: Color {
        switch self {
        case .classic, .clean, .creator:
            .white
        }
    }

    var backgroundColor: Color {
        switch self {
        case .classic:
            .black
        case .clean, .creator:
            .clear
        }
    }

    var backgroundOpacity: Double {
        switch self {
        case .classic:
            0.68
        case .clean, .creator:
            0
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .classic:
            6
        case .clean, .creator:
            0
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .classic:
            0
        case .clean:
            4
        case .creator:
            2
        }
    }

    nonisolated var exportFontName: String {
        switch self {
        case .classic, .creator:
            "Helvetica-Bold"
        case .clean:
            "HelveticaNeue-CondensedBlack"
        }
    }

    nonisolated var exportTextColor: CGColor {
        switch self {
        case .classic, .clean, .creator:
            CGColor(gray: 1.0, alpha: 1.0)
        }
    }

    nonisolated var exportBackgroundColor: CGColor {
        switch self {
        case .classic:
            CGColor(gray: 0.0, alpha: 0.68)
        case .clean, .creator:
            CGColor(gray: 0.0, alpha: 0.0)
        }
    }

    nonisolated var exportCornerRadius: CGFloat {
        switch self {
        case .classic:
            18
        case .clean, .creator:
            0
        }
    }

    nonisolated var exportStrokeColor: CGColor? {
        switch self {
        case .classic, .clean:
            nil
        case .creator:
            CGColor(gray: 0.0, alpha: 1.0)
        }
    }

    nonisolated var exportStrokeWidth: CGFloat {
        switch self {
        case .classic, .clean:
            0
        case .creator:
            -5
        }
    }
}
