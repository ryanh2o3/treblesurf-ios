// WaveIcons.swift
import SwiftUI

struct WaveIcon: View {
    enum Size {
        case flat, verySmall, small, medium, large, veryLarge
    }
    
    let size: Size
    
    var body: some View {
        switch size {
        case .flat:
            FlatWave()
        case .verySmall:
            VerySmallWave()
        case .small:
            SmallWave()
        case .medium:
            MediumWave()
        case .large:
            LargeWave()
        case .veryLarge:
            VeryLargeWave()
        }
    }
}

struct FlatWave: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 2, y: 12))
            path.addCurve(
                to: CGPoint(x: 22, y: 12),
                control1: CGPoint(x: 5, y: 11),
                control2: CGPoint(x: 19, y: 13)
            )
        }
        .stroke(Color.blue.opacity(0.5), lineWidth: 1)
        .frame(width: 24, height: 24)
    }
}

struct VerySmallWave: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 5, y: 45))
            path.addCurve(
                to: CGPoint(x: 45, y: 25),
                control1: CGPoint(x: 35, y: -5),
                control2: CGPoint(x: 45, y: 25)
            )
            path.addCurve(
                to: CGPoint(x: 45, y: 45),
                control1: CGPoint(x: 30, y: 30),
                control2: CGPoint(x: 45, y: 45)
            )
        }
        .stroke(Color.blue.opacity(0.7), lineWidth: 2)
        .frame(width: 50, height: 50)
    }
}

struct SmallWave: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 5, y: 45))
            path.addCurve(
                to: CGPoint(x: 45, y: 10),
                control1: CGPoint(x: 35, y: -5),
                control2: CGPoint(x: 45, y: 10)
            )
            path.addCurve(
                to: CGPoint(x: 45, y: 45),
                control1: CGPoint(x: 30, y: 30),
                control2: CGPoint(x: 45, y: 45)
            )
        }
        .stroke(Color.blue.opacity(0.8), lineWidth: 2)
        .frame(width: 50, height: 50)
    }
}


// Remaining wave implementations (MediumWave, LargeWave, VeryLargeWave) follow the same pattern
struct MediumWave: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 5, y: 45))
            path.addCurve(
                to: CGPoint(x: 45, y: 5),
                control1: CGPoint(x: 25, y: -10),
                control2: CGPoint(x: 45, y: 5)
            )
            path.addCurve(
                to: CGPoint(x: 45, y: 45),
                control1: CGPoint(x: 25, y: 35),
                control2: CGPoint(x: 45, y: 45)
            )
        }
        .stroke(Color.blue.opacity(0.8), lineWidth: 2.5)
        .frame(width: 50, height: 50)
    }
}

struct LargeWave: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 5, y: 45))
            path.addCurve(
                to: CGPoint(x: 25, y: 0),
                control1: CGPoint(x: 15, y: 15),
                control2: CGPoint(x: 20, y: 0)
            )
            path.addCurve(
                to: CGPoint(x: 45, y: 45),
                control1: CGPoint(x: 30, y: 0),
                control2: CGPoint(x: 40, y: 20)
            )
        }
        .stroke(Color.blue.opacity(0.9), lineWidth: 3)
        .frame(width: 50, height: 50)
    }
}

struct VeryLargeWave: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 5, y: 45))
            path.addCurve(
                to: CGPoint(x: 20, y: 0),
                control1: CGPoint(x: 10, y: 15),
                control2: CGPoint(x: 15, y: 0)
            )
            path.addCurve(
                to: CGPoint(x: 35, y: 10),
                control1: CGPoint(x: 25, y: 0),
                control2: CGPoint(x: 30, y: 0)
            )
            path.addCurve(
                to: CGPoint(x: 45, y: 45),
                control1: CGPoint(x: 40, y: 20),
                control2: CGPoint(x: 45, y: 30)
            )
        }
        .stroke(Color.blue, lineWidth: 3.5)
        .frame(width: 50, height: 50)
    }
}
