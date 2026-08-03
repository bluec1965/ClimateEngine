import SwiftUI

enum LiquidGlassTheme {
    static let backgroundTop = Color(red: 0.015, green: 0.105, blue: 0.130)
    static let backgroundMiddle = Color(red: 0.018, green: 0.075, blue: 0.095)
    static let backgroundBottom = Color(red: 0.008, green: 0.025, blue: 0.035)

    static let mint = Color(red: 0.08, green: 0.95, blue: 0.66)
    static let cyan = Color(red: 0.40, green: 0.90, blue: 1.00)
    static let ice = Color(red: 0.88, green: 0.98, blue: 1.00)
    static let petrol = Color(red: 0.01, green: 0.48, blue: 0.49)
    static let secondaryText = Color.white.opacity(0.64)
    static let tertiaryText = Color.white.opacity(0.45)
    static let divider = Color.white.opacity(0.10)

    static let brandGradient = LinearGradient(
        colors: [ice, cyan, mint],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let sensorGlyphGradient = LinearGradient(
        colors: [ice.opacity(0.98), cyan.opacity(0.92), petrol],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundMiddle, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static func statusGradient(_ color: Color) -> LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.92), color.opacity(0.95)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct LiquidGlassBackground: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LiquidGlassTheme.backgroundGradient

                Circle()
                    .fill(LiquidGlassTheme.mint.opacity(0.16))
                    .frame(
                        width: proxy.size.width * 0.72,
                        height: proxy.size.width * 0.72
                    )
                    .blur(radius: 100)
                    .offset(
                        x: -proxy.size.width * 0.34,
                        y: -proxy.size.height * 0.32
                    )

                Circle()
                    .fill(LiquidGlassTheme.cyan.opacity(0.11))
                    .frame(
                        width: proxy.size.width * 0.62,
                        height: proxy.size.width * 0.62
                    )
                    .blur(radius: 110)
                    .offset(
                        x: proxy.size.width * 0.38,
                        y: -proxy.size.height * 0.02
                    )

                Circle()
                    .fill(Color.blue.opacity(0.08))
                    .frame(
                        width: proxy.size.width * 0.8,
                        height: proxy.size.width * 0.8
                    )
                    .blur(radius: 130)
                    .offset(
                        x: proxy.size.width * 0.18,
                        y: proxy.size.height * 0.48
                    )
            }
        }
        .ignoresSafeArea()
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let glowColor: Color
    let raised: Bool

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.13),
                                        LiquidGlassTheme.cyan.opacity(0.055),
                                        Color.black.opacity(0.13)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.38),
                                        LiquidGlassTheme.cyan.opacity(0.20),
                                        LiquidGlassTheme.mint.opacity(0.10),
                                        Color.white.opacity(0.04)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(
                        color: Color.black.opacity(raised ? 0.48 : 0.34),
                        radius: raised ? 28 : 18,
                        x: 0,
                        y: raised ? 18 : 10
                    )
                    .shadow(
                        color: glowColor.opacity(raised ? 0.13 : 0.07),
                        radius: raised ? 24 : 16,
                        x: 0,
                        y: 3
                    )
            }
    }
}

private struct LiquidGlassInsetModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.075),
                                        LiquidGlassTheme.cyan.opacity(0.025),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    }
                    .shadow(color: Color.black.opacity(0.22), radius: 10, y: 6)
            }
    }
}

extension View {
    func liquidGlassCard(
        cornerRadius: CGFloat = 24,
        glowColor: Color = LiquidGlassTheme.cyan,
        raised: Bool = true
    ) -> some View {
        modifier(
            LiquidGlassCardModifier(
                cornerRadius: cornerRadius,
                glowColor: glowColor,
                raised: raised
            )
        )
    }

    func liquidGlassInset(cornerRadius: CGFloat = 18) -> some View {
        modifier(LiquidGlassInsetModifier(cornerRadius: cornerRadius))
    }
}

struct LiquidGlassIcon: View {
    let systemName: String
    var tint: Color = LiquidGlassTheme.mint
    var size: CGFloat = 42
    var symbolSize: CGFloat = 18

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: symbolSize, weight: .semibold))
            .foregroundStyle(LiquidGlassTheme.statusGradient(tint))
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.20),
                                        tint.opacity(0.18),
                                        Color.black.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.48), tint.opacity(0.24)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
                    .shadow(color: tint.opacity(0.20), radius: 12, y: 3)
                    .shadow(color: Color.black.opacity(0.30), radius: 8, y: 6)
            }
    }
}

struct LiquidGlassGlyph: View {
    let systemName: String
    var size: CGFloat = 42
    var symbolSize: CGFloat = 27

    var body: some View {
        ZStack {
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(LiquidGlassTheme.petrol.opacity(0.72))
                .offset(x: 1.2, y: 1.8)
                .blur(radius: 0.35)

            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(LiquidGlassTheme.sensorGlyphGradient)
                .shadow(color: LiquidGlassTheme.cyan.opacity(0.46), radius: 6, y: 2)
                .shadow(color: LiquidGlassTheme.mint.opacity(0.20), radius: 11, y: 4)

            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white.opacity(0.72), Color.white.opacity(0.08), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .blendMode(.screen)
                .offset(x: -0.45, y: -0.65)
        }
        .symbolRenderingMode(.monochrome)
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum LiquidGlassStatus {
    case ventilate
    case neutral
    case close

    var color: Color {
        switch self {
        case .ventilate: .green
        case .neutral: .orange
        case .close: .red
        }
    }
}

private struct LiquidGlassLens: View {
    let color: Color
    let size: CGFloat
    let vibrant: Bool

    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay {
                Circle()
                    .fill(color.opacity(vibrant ? 0.68 : 0.16))
            }
            .overlay {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(vibrant ? 0.72 : 0.38),
                                color.opacity(vibrant ? 0.70 : 0.24),
                                color.opacity(vibrant ? 0.46 : 0.10),
                                Color.black.opacity(vibrant ? 0.28 : 0.16)
                            ],
                            center: UnitPoint(x: 0.31, y: 0.24),
                            startRadius: 0,
                            endRadius: size * 0.70
                        )
                    )
            }
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(vibrant ? 0.70 : 0.48),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.22
                        )
                    )
                    .frame(width: size * 0.43, height: size * 0.31)
                    .offset(x: size * 0.12, y: size * 0.10)
                    .blur(radius: 0.8)
            }
            .shadow(
                color: color.opacity(vibrant ? 0.42 : 0.22),
                radius: size * 0.25,
                y: size * 0.08
            )
            .shadow(color: Color.black.opacity(0.36), radius: size * 0.20, y: size * 0.16)
    }
}

struct LiquidGlassStatusIcon: View {
    let status: LiquidGlassStatus
    var size: CGFloat = 34
    var symbolSize: CGFloat = 14

    var body: some View {
        ZStack {
            LiquidGlassLens(color: status.color, size: size, vibrant: false)

            Image(systemName: status == .neutral ? "minus" : "wind")
                .font(.system(size: symbolSize, weight: .bold))
                .foregroundStyle(LiquidGlassTheme.ice.opacity(0.96))
                .shadow(color: Color.black.opacity(0.28), radius: 1, y: 1)

            if status == .close {
                Capsule()
                    .fill(LiquidGlassTheme.ice.opacity(0.98))
                    .frame(width: size * 0.58, height: max(2, size * 0.075))
                    .rotationEffect(.degrees(-45))
                    .shadow(color: Color.black.opacity(0.30), radius: 1, y: 1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct LiquidGlassIndicatorIcon: View {
    let systemName: String
    let tint: Color
    var size: CGFloat = 26
    var symbolSize: CGFloat = 10
    var vibrant = false

    var body: some View {
        ZStack {
            LiquidGlassLens(color: tint, size: size, vibrant: vibrant)

            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .bold))
                .foregroundStyle(LiquidGlassTheme.ice.opacity(0.98))
                .shadow(color: Color.black.opacity(0.30), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct LiquidGlassSectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(1.4)
            .foregroundStyle(LiquidGlassTheme.brandGradient)
    }
}

struct LiquidGlassDivider: View {
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [Color.clear, LiquidGlassTheme.cyan.opacity(0.24), Color.clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
    }
}
