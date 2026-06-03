//
//  LiquidGlassChrome.swift
//  Shepherd
//
//  Floating liquid-glass navigation chrome (native on iOS 18+, glassEffect on iOS 26+).
//

import SwiftUI

// MARK: - Mesh background

struct LiquidMeshBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ShepherdColors.surfaceDeep.ignoresSafeArea()

            if colorScheme == .dark {
                Circle()
                    .fill(ShepherdColors.meshBlue.opacity(0.55))
                    .frame(width: 340, height: 340)
                    .blur(radius: 90)
                    .offset(x: -120, y: -220)

                Circle()
                    .fill(ShepherdColors.meshViolet.opacity(0.45))
                    .frame(width: 300, height: 300)
                    .blur(radius: 80)
                    .offset(x: 140, y: -80)

                Circle()
                    .fill(ShepherdColors.liquidAccent.opacity(0.18))
                    .frame(width: 260, height: 260)
                    .blur(radius: 70)
                    .offset(x: 60, y: 320)
            } else {
                Circle()
                    .fill(ShepherdColors.liquidAccent.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(x: -80, y: -160)
            }

            LinearGradient(
                colors: [
                    Color.black.opacity(colorScheme == .dark ? 0.15 : 0.02),
                    Color.clear,
                    Color.black.opacity(colorScheme == .dark ? 0.35 : 0.06),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }
}

// MARK: - Glass surface

struct LiquidGlassSurface<S: Shape>: View {
    let shape: S
    var tint: Color = .clear
    var interactive: Bool = false

    var body: some View {
        Group {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(glassStyle(interactive: interactive), in: shape)
            } else {
                shape
                    .fill(.ultraThinMaterial)
                    .background(shape.fill(ShepherdColors.glassFill))
                    .overlay(shape.stroke(ShepherdColors.glassBorder, lineWidth: 0.5))
            }
        }
    }

    @available(iOS 26.0, *)
    private func glassStyle(interactive: Bool) -> Glass {
        var glass = Glass.regular
        if tint != .clear {
            glass = glass.tint(tint)
        }
        if interactive {
            glass = glass.interactive()
        }
        return glass
    }
}

// MARK: - Floating tab bar (iOS 15–17 fallback)

struct FloatingLiquidTabBar: View {
    @Binding var selection: Int
    let items: [(title: String, icon: String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                tabItem(title: item.title, icon: item.icon, index: index)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .background {
            LiquidGlassSurface(shape: Capsule(style: .continuous), interactive: true)
                .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func tabItem(title: String, icon: String, index: Int) -> some View {
        let isSelected = selection == index

        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                selection = index
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))

                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .medium))
            }
            .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.45))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(ShepherdColors.liquidAccent.opacity(0.9))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Navigation (iOS 15 compatible)

/// Wraps `NavigationStack` on iOS 16+ and falls back to `NavigationView` on iOS 15.
struct ShepherdNavigationStack<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        if #available(iOS 16.0, *) {
            NavigationStack {
                content()
            }
        } else {
            NavigationView {
                content()
            }
            .navigationViewStyle(.stack)
        }
    }
}

// MARK: - Screen chrome

struct ShepherdScreenChrome<Content: View>: View {
    let title: String
  var showsElderTools: Bool = false
  var onElderTools: (() -> Void)? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        ShepherdNavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                content()
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 120)
            }
            .background { LiquidMeshBackground() }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ShepherdNavigationBarStyle())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Group {
                        if showsElderTools, let onElderTools {
                            Button(action: onElderTools) {
                                Image(systemName: "person.badge.key.fill")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background {
                                        LiquidGlassSurface(
                                            shape: Circle(),
                                            tint: ShepherdColors.liquidAccent.opacity(0.35),
                                            interactive: true
                                        )
                                    }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ShepherdNavigationBarStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(.automatic, for: .navigationBar)
        } else if #available(iOS 16.0, *) {
            content
                .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
        } else {
            content
        }
    }
}

// MARK: - View extensions

extension View {
    func shepherdLiquidScreen() -> some View {
        background { LiquidMeshBackground() }
            .modifier(ShepherdNavigationBarStyle())
    }

    @ViewBuilder
    func shepherdTabBarMinimize() -> some View {
        if #available(iOS 26.0, *) {
            self.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            self
        }
    }
}
