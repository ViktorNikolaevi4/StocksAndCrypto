import SwiftUI

struct SparklineView: View {
    let data: [Double]
    let rising: Bool
    var color: Color? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let minV = data.min() ?? 0
            let maxV = data.max() ?? 1
            let span = max(maxV - minV, 0.0001)
            let stepX = data.count > 1 ? w / CGFloat(data.count - 1) : 0
            let lineColor = color ?? (rising ? Color.green : Color.red)

            // линия
            Path { p in
                for (i, v) in data.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = h - CGFloat((v - minV) / span) * h
                    if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                    else { p.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(rising ? Color.green : Color.red, lineWidth: 1.6)

            // мягкая подзаливка
            Path { p in
                guard !data.isEmpty else { return }
                p.move(to: CGPoint(x: 0, y: h))
                for (i, v) in data.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = h - CGFloat((v - minV) / span) * h
                    p.addLine(to: CGPoint(x: x, y: y))
                }
                p.addLine(to: CGPoint(x: w, y: h))
                p.closeSubpath()
            }
            .fill((rising ? Color.green : Color.red).opacity(0.12))
        }
    }
}
