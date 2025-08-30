import SwiftUI

/// Гладкий мини-график (sparkline) c заливкой под кривой.
/// Данные нормализуются по высоте в переданном фрейме.
struct SparklineView: View {
    var data: [Double]
    var rising: Bool
    var colorOverride: Color? = nil
    var lineWidth: CGFloat = 2.2
    /// Насколько «изогнута» кривая: 0.0 — ломаная, ~0.5…1.0 — мягкая.
    var curvature: CGFloat = 1.5

    var body: some View {
           GeometryReader { geo in
               let rect = geo.frame(in: .local)
               let points = makePoints(in: rect, values: data)

               let curve = smoothPath(points: points, t: curvature)
               let fill  = areaPath(from: curve, in: rect)

               // Если цвет не задан — подсветим по тренду (auto),
               // если задан — используем его как есть.
               let lineColor: Color = colorOverride ?? (rising ? .green : .red)

               ZStack {
                   fill.fill(
                       LinearGradient(
                           colors: [ lineColor.opacity(0.22),
                                     lineColor.opacity(0.05),
                                     .clear ],
                           startPoint: .top, endPoint: .bottom
                       )
                   )

                   curve
                       .stroke(style: StrokeStyle(lineWidth: lineWidth,
                                                  lineCap: .round,
                                                  lineJoin: .round))
                       .foregroundStyle(lineColor)
               }
               .drawingGroup()
           }
       }

    // MARK: - Geometry & Paths

    private func makePoints(in rect: CGRect, values: [Double]) -> [CGPoint] {
        guard values.count > 1 else { return [] }
        let minV = values.min() ?? 0
        let maxV = values.max() ?? 1
        let range = max(maxV - minV, 1e-9)

        let w = rect.width
        let h = rect.height
        let stepX = w / CGFloat(values.count - 1)

        return values.enumerated().map { (i, v) in
            let x = CGFloat(i) * stepX
            let yNorm = (v - minV) / range
            // координаты растут вниз, поэтому инвертируем
            let y = h * (1 - CGFloat(yNorm))
            return CGPoint(x: x, y: y)
        }
    }

    /// Гладкая кривая: Catmull–Rom → cubic Bézier
    private func smoothPath(points: [CGPoint], t: CGFloat) -> Path {
        var pts = points
        var path = Path()

        guard pts.count > 1 else { return path }
        if pts.count == 2 {
            path.move(to: pts[0])
            path.addLine(to: pts[1])
            return path
        }

        // дублируем крайние для корректных касательных
        let first = pts.first!
        let last  = pts.last!
        pts.insert(first, at: 0)
        pts.append(last)

        path.move(to: pts[1])

        for i in 1 ..< pts.count - 2 {
            let p0 = pts[i - 1]
            let p1 = pts[i]
            let p2 = pts[i + 1]
            let p3 = pts[i + 2]

            // Catmull–Rom → Bézier:
            // CP1 = P1 + (P2 - P0) / 6 * t
            // CP2 = P2 - (P3 - P1) / 6 * t
            let cp1 = CGPoint(
                x: p1.x + (p2.x - p0.x) / 6.0 * t,
                y: p1.y + (p2.y - p0.y) / 6.0 * t
            )
            let cp2 = CGPoint(
                x: p2.x - (p3.x - p1.x) / 6.0 * t,
                y: p2.y - (p3.y - p1.y) / 6.0 * t
            )

            path.addCurve(to: p2, control1: cp1, control2: cp2)
        }

        return path
    }

    /// Закрытая фигура для заливки под кривой
    private func areaPath(from curve: Path, in rect: CGRect) -> Path {
        var p = curve
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}
