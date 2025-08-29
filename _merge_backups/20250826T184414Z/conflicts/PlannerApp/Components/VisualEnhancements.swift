//
//  VisualEnhancements.swift
//  PlannerApp
//
//  Modern visual enhancements including animations, glass morphism, and improved visual hierarchy
//

import SwiftUI

// MARK: - Glass Morphism Card
struct GlassMorphismCard<Content: View>: View {
    let content: Content
    @EnvironmentObject var themeManager: ThemeManager
    
    var cornerRadius: CGFloat = 16
    var shadowIntensity: CGFloat = 0.1
    
    init(
        cornerRadius: CGFloat = 16,
        shadowIntensity: CGFloat = 0.1,
        @ViewBuilder content: () -> Content
    ) {
        self.cornerRadius = cornerRadius
        self.shadowIntensity = shadowIntensity
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                themeManager.currentTheme.primaryAccentColor.opacity(0.05),
                                themeManager.currentTheme.secondaryAccentColor.opacity(0.02)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.white.opacity(0.6),
                                Color.white.opacity(0.1)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: themeManager.currentTheme.primaryAccentColor.opacity(shadowIntensity),
                radius: 20,
                x: 0,
                y: 10
            )
    }
}

// MARK: - Animated Progress Ring
struct AnimatedProgressRing: View {
    let progress: Double
    let title: String
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var animatedProgress: Double = 0
    
    var ringWidth: CGFloat = 12
    var size: CGFloat = 100
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(
                    themeManager.currentTheme.secondaryAccentColor.opacity(0.3),
                    lineWidth: ringWidth
                )
                .frame(width: size, height: size)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            themeManager.currentTheme.primaryAccentColor,
                            themeManager.currentTheme.secondaryAccentColor
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.5), value: animatedProgress)
            
            // Center content
            VStack(spacing: 4) {
                Text("\(Int(animatedProgress * 100))%")
                    .font(.system(size: size * 0.2, weight: .bold, design: .rounded))
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                    .contentTransition(.numericText())
                
                Text(title)
                    .font(.system(size: size * 0.1, weight: .medium))
                    .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    .multilineTextAlignment(.center)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).delay(0.2)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.easeInOut(duration: 1.0)) {
                animatedProgress = newValue
            }
        }
    }
}

// MARK: - Floating Action Button
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var isPressed = false
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Button(action: {
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            #endif
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                rotationAngle += 180
            }
            
            action()
        }) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    themeManager.currentTheme.primaryAccentColor,
                                    themeManager.currentTheme.primaryAccentColor.opacity(0.8)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .shadow(
                    color: themeManager.currentTheme.primaryAccentColor.opacity(0.4),
                    radius: isPressed ? 8 : 16,
                    x: 0,
                    y: isPressed ? 4 : 8
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .rotationEffect(.degrees(rotationAngle))
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Animated Card Flip
struct FlipCard<Front: View, Back: View>: View {
    let front: Front
    let back: Back
    
    @State private var isFlipped = false
    @State private var flipDegrees = 0.0
    
    init(@ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.front = front()
        self.back = back()
    }
    
    var body: some View {
        ZStack {
            if flipDegrees < 90 {
                front
            } else {
                back
                    .rotationEffect(.degrees(180))
            }
        }
        .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.6)) {
                flipDegrees += 180
                isFlipped.toggle()
            }
        }
    }
}

// MARK: - Particle System for Celebrations
struct ParticleSystem: View {
    @State private var particles: [Particle] = []
    @State private var isAnimating = false
    
    struct Particle: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var velocity: CGVector
        var color: Color
        var scale: CGFloat
        var opacity: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: 8, height: 8)
                        .scaleEffect(particle.scale)
                        .opacity(particle.opacity)
                        .position(x: particle.x, y: particle.y)
                }
            }
        }
        .onAppear {
            if !isAnimating {
                createParticles()
                animateParticles()
            }
        }
    }
    
    private func createParticles() {
        particles = (0..<50).map { _ in
            Particle(
                x: CGFloat.random(in: 50...350),
                y: 400,
                velocity: CGVector(
                    dx: CGFloat.random(in: -200...200),
                    dy: CGFloat.random(in: -400...(-200))
                ),
                color: [Color.blue, Color.green, Color.orange, Color.red, Color.purple].randomElement()!,
                scale: CGFloat.random(in: 0.5...1.5),
                opacity: 1.0
            )
        }
    }
    
    private func animateParticles() {
        isAnimating = true
        
        withAnimation(.linear(duration: 3.0)) {
            for i in particles.indices {
                particles[i].x += particles[i].velocity.dx * 0.01
                particles[i].y += particles[i].velocity.dy * 0.01
                particles[i].opacity = 0.0
                particles[i].scale *= 0.1
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            particles.removeAll()
            isAnimating = false
        }
    }
}

// MARK: - Shimmer Loading Effect
struct ShimmerView: View {
    @State private var shimmerOffset: CGFloat = -200
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(themeManager.currentTheme.secondaryBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color.clear,
                                Color.white.opacity(0.4),
                                Color.clear
                            ]),
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
                    .animation(
                        .linear(duration: 1.5).repeatForever(autoreverses: false),
                        value: shimmerOffset
                    )
            )
            .onAppear {
                shimmerOffset = 200
            }
    }
}

// MARK: - Interactive 3D Card
struct Interactive3DCard<Content: View>: View {
    let content: Content
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var rotation: CGFloat = 0
    @State private var translation: CGSize = .zero
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(themeManager.currentTheme.secondaryBackgroundColor)
                    .shadow(
                        color: .black.opacity(0.1),
                        radius: 10 + abs(translation.height) * 0.1,
                        x: translation.width * 0.1,
                        y: 5 + translation.height * 0.1
                    )
            )
            .rotation3DEffect(
                .degrees(rotation),
                axis: (translation.height, -translation.width, 0.0)
            )
            .offset(translation)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        translation = CGSize(
                            width: value.translation.width * 0.1,
                            height: value.translation.height * 0.1
                        )
                        rotation = sqrt(pow(translation.width, 2) + pow(translation.height, 2)) * 0.5
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            translation = .zero
                            rotation = 0
                        }
                    }
            )
    }
}

// MARK: - Breathing Animation
struct BreathingView<Content: View>: View {
    let content: Content
    @State private var scale: CGFloat = 1.0
    
    var duration: Double = 2.0
    var scaleRange: ClosedRange<CGFloat> = 0.95...1.05
    
    init(
        duration: Double = 2.0,
        scaleRange: ClosedRange<CGFloat> = 0.95...1.05,
        @ViewBuilder content: () -> Content
    ) {
        self.duration = duration
        self.scaleRange = scaleRange
        self.content = content()
    }
    
    var body: some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    scale = scaleRange.upperBound
                }
            }
    }
}

// MARK: - Enhanced Visual Components Preview
struct VisualEnhancementsPreview: View {
    @StateObject private var themeManager = ThemeManager()
    @State private var showParticles = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Glass Morphism Card
                GlassMorphismCard {
                    VStack {
                        Text("Glass Morphism Card")
                            .font(.headline)
                        Text("Modern translucent design")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .environmentObject(themeManager)
                
                // Animated Progress Ring
                HStack(spacing: 30) {
                    AnimatedProgressRing(progress: 0.75, title: "Tasks")
                        .environmentObject(themeManager)
                    
                    AnimatedProgressRing(progress: 0.45, title: "Goals")
                        .environmentObject(themeManager)
                }
                
                // Interactive 3D Card
                Interactive3DCard {
                    VStack {
                        Text("3D Interactive Card")
                            .font(.title2.bold())
                        Text("Drag to rotate")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 100)
                }
                .environmentObject(themeManager)
                
                // Flip Card
                FlipCard(
                    front: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.blue.gradient)
                            Text("Tap to Flip")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .frame(height: 100)
                    },
                    back: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.green.gradient)
                            Text("Back Side")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .frame(height: 100)
                    }
                )
                
                // Shimmer Loading
                VStack(alignment: .leading, spacing: 8) {
                    Text("Loading Shimmer Effect")
                        .font(.headline)
                    
                    ShimmerView()
                        .frame(height: 60)
                        .environmentObject(themeManager)
                }
                
                // Breathing Animation
                BreathingView {
                    Circle()
                        .fill(.purple.gradient)
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("Zen")
                                .foregroundColor(.white)
                                .font(.headline)
                        )
                }
                
                // Celebration Button
                Button("Celebrate! 🎉") {
                    showParticles = true
                }
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding()
                .background(.orange.gradient)
                .cornerRadius(16)
            }
            .padding()
        }
        .overlay(
            Group {
                if showParticles {
                    ParticleSystem()
                        .allowsHitTesting(false)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                showParticles = false
                            }
                        }
                }
            }
        )
        .overlay(
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FloatingActionButton(icon: "plus") {
                        // Add action
                    }
                    .environmentObject(themeManager)
                    .padding()
                }
            }
        )
    }
}

#Preview {
    VisualEnhancementsPreview()
}
