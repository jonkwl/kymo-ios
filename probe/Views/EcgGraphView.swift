import SwiftUI

struct EcgGraphView: View {
    let samples: [Double]
    
    private var dynamicRange: Double {
        let maxVal = samples.map(abs).max() ?? 1000
        return max(2000, maxVal * 1.2)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let middle = height / 2
            
            let scaleY = height / CGFloat(dynamicRange)
            let stepX = width / CGFloat(max(1, samples.count - 1))
            
            ZStack {
                ecgPath(stepX: stepX, middle: middle, scaleY: scaleY)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 5)
                    .blur(radius: 3)
                
                ecgPath(stepX: stepX, middle: middle, scaleY: scaleY)
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [.white, .white]),
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .drawingGroup()
    }
    
    private func ecgPath(stepX: CGFloat, middle: CGFloat, scaleY: CGFloat) -> Path {
        var path = Path()
        guard samples.count > 1 else { return path }
        
        let startY = middle - CGFloat(samples[0]) * (scaleY / 2)
        path.move(to: CGPoint(x: 0, y: startY))
        
        for index in 1..<samples.count {
            let x = CGFloat(index) * stepX
            let y = middle - CGFloat(samples[index]) * (scaleY / 2)
            path.addLine(to: CGPoint(x: x, y: y))
        }
        
        return path
    }
}

struct EcgGridView: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 30
        
        for x in stride(from: 0, through: rect.width, by: step) {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: rect.height))
        }
        for y in stride(from: 0, through: rect.height, by: step) {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: rect.width, y: y))
        }
        return path
    }
}
