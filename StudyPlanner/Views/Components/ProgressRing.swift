//
//  ProgressRing.swift
//  StudyPlanner
//

import SwiftUI

struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 11
    var diameter: CGFloat = 220
    var overflowWarning: Bool = false

    private var clamped: Double { min(1, max(0, progress)) }

    var body: some View {
        ZStack {
            // Track
            Circle()
                .stroke(
                    overflowWarning ? Color.red.opacity(0.15) : Color(.systemGray5),
                    lineWidth: lineWidth
                )

            // Arc
            if overflowWarning {
                Circle()
                    .stroke(Color.red, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            } else {
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color.examGreen.opacity(0.55), Color.examGreen]),
                            center: .center,
                            startAngle: .degrees(-90),
                            endAngle: .degrees(-90 + 360 * clamped)
                        ),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.55, dampingFraction: 0.72), value: clamped)
            }

            // Centre label
            if overflowWarning {
                VStack(spacing: 2) {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: diameter * 0.28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.red)
                    Text("Won't finish")
                        .font(.system(size: diameter * 0.09, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
            } else {
                HStack(alignment: .lastTextBaseline, spacing: 1) {
                    Text("\(Int((clamped * 100).rounded()))")
                        .font(.system(size: diameter * 0.27, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.examGreen.opacity(0.7), Color.examGreen],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4), value: Int((clamped * 100).rounded()))
                    Text("%")
                        .font(.system(size: diameter * 0.11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.examGreen.opacity(0.7))
                        .padding(.bottom, 4)
                }
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeOut(duration: 0.3), value: overflowWarning)
    }
}

#Preview {
    VStack(spacing: 32) {
        ProgressRing(progress: 0.6)
        ProgressRing(progress: 0.6, overflowWarning: true)
    }.padding()
}
