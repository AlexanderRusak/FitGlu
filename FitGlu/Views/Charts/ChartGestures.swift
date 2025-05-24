import SwiftUI
import Charts

struct ChartGestures: View {

    let proxy:      ChartProxy
    let dayDomain:  ClosedRange<Date>

    @Binding var scale:  CGFloat
    @Binding var offset: TimeInterval

    @State private var lastGesture: CGFloat = 1
    @State private var plotWidth:   CGFloat = 1

    private let cfg = ChartConfig.default

    private var dayInterval: TimeInterval { dayDomain.length }

    var body: some View {
        GeometryReader { _ in
            Color.clear
                .onAppear { plotWidth = proxy.plotAreaSize.width }
                .onChange(of: proxy.plotAreaSize) { plotWidth = $0.width }
                .contentShape(Rectangle())                       // hit-area

                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let secPerPt = dayInterval / Double(plotWidth)
                            offset = (offset - Double(g.translation.width)*secPerPt*cfg.panDamping)
                                .clamped(to: -dayInterval/2 ... dayInterval/2)
                        }
                )
        }
        .gesture(                                             // pinch-zoom
            MagnificationGesture()
                .onChanged { value in
                    let amp = pow(value / lastGesture, cfg.zoomAmplifier)
                    lastGesture = value
                    scale = (scale * amp).clamped(to: cfg.maxZoom)
                }
                .onEnded { _ in lastGesture = 1 }
        )
    }
}
