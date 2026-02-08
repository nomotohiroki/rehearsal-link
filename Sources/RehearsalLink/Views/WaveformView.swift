import SwiftUI

struct WaveformView: View {
    let samples: [WaveformSample]
    let segments: [AudioSegment]
    let selectedSegmentId: UUID?
    let totalDuration: TimeInterval
    let width: CGFloat
    var playbackPosition: Double = 0 // 0.0 to 1.0
    var color: Color = .blue
    var onSeek: ((Double) -> Void)? = nil
    var onSelectSegment: ((UUID) -> Void)? = nil
    var onUpdateSegmentType: ((UUID, SegmentType) -> Void)? = nil
    var onMoveBoundary: ((Int, TimeInterval) -> Void)? = nil
    var onMergeWithNext: ((UUID) -> Void)? = nil
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景でのクリック判定用 (Seek & Select)
                // DragGesture(minimumDistance: 0) を使用して、ズーム時の座標ずれを防ぐ
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let locationX = value.location.x
                                let progress = locationX / width
                                onSeek?(Double(progress))
                                
                                // 座標ベースでのセグメント選択
                                let time = Double(progress) * totalDuration
                                if let hitSegment = segments.first(where: { $0.startTime <= time && time < $0.endTime }) {
                                    onSelectSegment?(hitSegment.id)
                                }
                            }
                    )
                
                // セグメント背景
                ForEach(segments) { segment in
                    ZStack {
                        segmentColor(for: segment)
                        if selectedSegmentId == segment.id {
                            Rectangle()
                                .stroke(Color.accentColor, lineWidth: 2)
                        }
                    }
                    .frame(width: max(0, width * CGFloat(segment.duration / totalDuration)))
                    .offset(x: width * CGFloat(segment.startTime / totalDuration))
                    .allowsHitTesting(false) // クリックは背景のDragGestureで一括処理
                    .contextMenu {
                        Section("タイプ変更") {
                            Button("演奏として設定") {
                                onUpdateSegmentType?(segment.id, .performance)
                            }
                            Button("会話として設定") {
                                onUpdateSegmentType?(segment.id, .conversation)
                            }
                            Button("無音として設定") {
                                onUpdateSegmentType?(segment.id, .silence)
                            }
                        }
                        
                        Section("編集") {
                            Button("次のセグメントと結合") {
                                onMergeWithNext?(segment.id)
                            }
                            .disabled(segment.id == segments.last?.id)
                        }
                    }
                }
                
                // 境界ハンドル
                ForEach(0..<max(0, segments.count - 1), id: \.self) { index in
                    let segment = segments[index]
                    Rectangle()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 4)
                        .offset(x: width * CGFloat(segment.endTime / totalDuration) - 2)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newX = value.location.x
                                    let newTime = Double(newX / width) * totalDuration
                                    onMoveBoundary?(index, newTime)
                                }
                        )
                        .onHover { inside in
                            if inside {
                                NSCursor.resizeLeftRight.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                }
                
                Path { path in
                    let height = geometry.size.height
                    let middle = height / 2
                    
                    guard samples.count > 1 else { return }
                    
                    let step = width / CGFloat(samples.count - 1)
                    
                    // Top part of the waveform
                    path.move(to: CGPoint(x: 0, y: middle + CGFloat(samples[0].max) * middle))
                    for i in 1..<samples.count {
                        path.addLine(to: CGPoint(x: CGFloat(i) * step, y: middle + CGFloat(samples[i].max) * middle))
                    }
                    
                    // Bottom part of the waveform (reversed)
                    for i in (0..<samples.count).reversed() {
                        path.addLine(to: CGPoint(x: CGFloat(i) * step, y: middle + CGFloat(samples[i].min) * middle))
                    }
                    
                    path.closeSubpath()
                }
                .fill(color)
                .allowsHitTesting(false)
                
                // 再生カーソル
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .offset(x: width * CGFloat(playbackPosition))
            }
        }
    }
    
    private func segmentColor(for segment: AudioSegment) -> Color {
        if segment.isExcludedFromExport {
            return Color.gray.opacity(0.3)
        }
        
        switch segment.type {
        case .performance:
            return Color.blue.opacity(0.2)
        case .conversation:
            if segment.transcription != nil {
                return Color.purple.opacity(0.3)
            }
            return Color.green.opacity(0.2)
        case .silence:
            return Color.gray.opacity(0.1)
        }
    }
}
