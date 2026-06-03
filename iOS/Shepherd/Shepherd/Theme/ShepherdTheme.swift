//
//  ShepherdTheme.swift
//  Shepherd
//

import SwiftUI

// MARK: - Color Palette

enum ShepherdColors {
    // Brand — Coral (buttons, highlights)
    static let accent = Color(red: 1.0, green: 0.36, blue: 0.28)
    static let accentLight = Color(red: 1.0, green: 0.46, blue: 0.38)
    static let accentDark = Color(red: 0.90, green: 0.26, blue: 0.18)

    // Liquid glass — electric blue (nav, primary chrome)
    static let liquidAccent = Color(red: 0.20, green: 0.48, blue: 1.0)
    static let liquidAccentSoft = Color(red: 0.35, green: 0.58, blue: 1.0)

    static let secondary = Color(red: 0.30, green: 0.39, blue: 0.34)

    // Surfaces
    static let surfaceDeep = Color(red: 0.04, green: 0.05, blue: 0.10)
    static let surfaceDark = Color(red: 0.06, green: 0.07, blue: 0.12)
    static let surfaceElevated = Color(red: 0.10, green: 0.11, blue: 0.16)
    static let surfaceCard = Color(red: 0.12, green: 0.13, blue: 0.18)
    static let glassFill = Color.black.opacity(0.38)

    // Mesh blobs
    static let meshBlue = Color(red: 0.12, green: 0.28, blue: 0.72)
    static let meshViolet = Color(red: 0.28, green: 0.14, blue: 0.55)

    // Text
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)
    static let textTertiary = Color.white.opacity(0.38)

    static let textPrimaryLight = Color(hue: 0.72, saturation: 0.20, brightness: 0.15)
    static let textSecondaryLight = Color(hue: 0.72, saturation: 0.10, brightness: 0.40)
    static let surfaceLight = Color(hue: 0.72, saturation: 0.05, brightness: 0.97)
    static let surfaceCardLight = Color.white.opacity(0.72)

    static let elderBadge = Color(hue: 0.72, saturation: 0.60, brightness: 0.90)
    static let pioneerBadge = Color(hue: 0.12, saturation: 0.65, brightness: 0.95)

    static let glassBorder = Color.white.opacity(0.10)
    static let glassBorderLight = Color.black.opacity(0.06)
}

// MARK: - Typography

enum ShepherdFont {
    static func title(_ weight: Font.Weight = .bold) -> Font {
        .system(.title2, design: .rounded).weight(weight)
    }

    static func headline(_ weight: Font.Weight = .semibold) -> Font {
        .system(.headline, design: .rounded).weight(weight)
    }

    static func body(_ weight: Font.Weight = .regular) -> Font {
        .system(.body, design: .default).weight(weight)
    }

    static func caption(_ weight: Font.Weight = .medium) -> Font {
        .system(.caption, design: .default).weight(weight)
    }

    static func largeTitle(_ weight: Font.Weight = .bold) -> Font {
        .system(.largeTitle, design: .rounded).weight(weight)
    }

    static func subheadline(_ weight: Font.Weight = .regular) -> Font {
        .system(.subheadline, design: .default).weight(weight)
    }

    static func display(_ weight: Font.Weight = .bold) -> Font {
        .system(size: 34, weight: weight, design: .rounded)
    }
}

// MARK: - Corner Radii

enum ShepherdRadius {
    static let small: CGFloat = 12
    static let medium: CGFloat = 20
    static let large: CGFloat = 26
    static let extraLarge: CGFloat = 32
    static let pill: CGFloat = 999
}

// MARK: - Shadows

enum ShepherdShadow {
    static let subtle: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
        Color.black.opacity(0.28), 20, 0, 8
    )
    static let elevated: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
        Color.black.opacity(0.45), 32, 0, 16
    )
    static let glow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (
        ShepherdColors.liquidAccent.opacity(0.35), 20, 0, 4
    )
}

// MARK: - Glass card

struct GlassCard: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    var padding: CGFloat = 20
    var cornerRadius: CGFloat = ShepherdRadius.extraLarge

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.clear)
                        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(ShepherdColors.glassFill)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .stroke(ShepherdColors.glassBorder, lineWidth: 0.5)
                        )
                        .shadow(
                            color: ShepherdShadow.subtle.color,
                            radius: ShepherdShadow.subtle.radius,
                            x: ShepherdShadow.subtle.x,
                            y: ShepherdShadow.subtle.y
                        )
                }
            }
    }
}

struct CompactGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(GlassCard(padding: 14, cornerRadius: ShepherdRadius.large))
    }
}

struct TapScale: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .opacity(isPressed ? 0.88 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isPressed)
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

struct SlideUpEntrance: ViewModifier {
    @State private var appeared = false
    let delay: Double

    func body(content: Content) -> some View {
        content
            .offset(y: appeared ? 0 : 20)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.82).delay(delay)) {
                    appeared = true
                }
            }
    }
}

struct AdaptiveTextPrimary: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(
            colorScheme == .dark ? ShepherdColors.textPrimary : ShepherdColors.textPrimaryLight
        )
    }
}

struct AdaptiveTextSecondary: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content.foregroundStyle(
            colorScheme == .dark ? ShepherdColors.textSecondary : ShepherdColors.textSecondaryLight
        )
    }
}

// MARK: - Primary button

struct LiquidPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(ShepherdFont.headline(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                if #available(iOS 26.0, *) {
                    Capsule(style: .continuous)
                        .fill(.clear)
                        .glassEffect(
                            .regular.tint(ShepherdColors.liquidAccent).interactive(),
                            in: Capsule(style: .continuous)
                        )
                } else {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [ShepherdColors.liquidAccent, ShepherdColors.liquidAccentSoft],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension View {
    func glassCard(padding: CGFloat = 20, cornerRadius: CGFloat = ShepherdRadius.extraLarge) -> some View {
        modifier(GlassCard(padding: padding, cornerRadius: cornerRadius))
    }

    func compactGlassCard() -> some View {
        modifier(CompactGlassCard())
    }

    func tapScale() -> some View {
        modifier(TapScale())
    }

    func slideUpEntrance(delay: Double = 0) -> some View {
        modifier(SlideUpEntrance(delay: delay))
    }

    func adaptiveTextPrimary() -> some View {
        modifier(AdaptiveTextPrimary())
    }

    func adaptiveTextSecondary() -> some View {
        modifier(AdaptiveTextSecondary())
    }

    func shepherdBackground(_ colorScheme: ColorScheme) -> some View {
        background {
            if colorScheme == .dark {
                LiquidMeshBackground()
            } else {
                ShepherdColors.surfaceLight
            }
        }
    }
}
