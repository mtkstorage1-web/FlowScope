import SwiftUI

struct SmoothCurveShape: Shape {
    let points: [CGPoint]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard points.count > 1 else { return path }
        
        let points = points.map { point in
            CGPoint(
                x: point.x * rect.width,
                y: (1 - point.y) * rect.height
            )
        }
        
        path.move(to: points[0])
        
        for i in 0..<points.count - 1 {
            let current = points[i]
            let next = points[i + 1]
            let midX = (current.x + next.x) / 2
            path.addCurve(
                to: next,
                control1: CGPoint(x: midX, y: current.y),
                control2: CGPoint(x: midX, y: next.y)
            )
        }
        
        return path
    }
}
