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

    @State private var hoverPosition: Double? = nil
    @State private var isHoveringBoundary: Int? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景でのクリック判定用 (Seek & Select)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { value in
                                let progress = value.location.x / width
                                onSeek?(Double(progress))
                                selectSegment(at: Double(progress) * totalDuration)
                            }
                    )
                    .onContinuousHover { phase in
                        switch phase {
                        case let .active(location):
                            hoverPosition = Double(location.x / width)
                        case .ended:
                            hoverPosition = nil
                        }
                    }

                // セグメント背景
                ForEach(segments) { segment in
                    ZStack {
                        // Liquid Glass style segment background with gradient
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        segmentColor(for: segment)
                                            .opacity(selectedSegmentId == segment.id ? 0.5 : 0.3),
                                        segmentColor(for: segment)
                                            .opacity(selectedSegmentId == segment.id ? 0.3 : 0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        if selectedSegmentId == segment.id {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .stroke(Color.accentColor, lineWidth: 2)
                                .shadow(color: Color.accentColor.opacity(0.5), radius: 8)
                                .transition(.scale(scale: 0.98).combined(with: .opacity))
                        }

                        if segment.isExcludedFromExport {
                            Rectangle()
                                .fill(
                                    ImagePaint(image: Image(systemName: "line.diagonal"), sourceRect: CGRect(x: 0, y: 0, width: 1, height: 1), scale: 0.1)
                                )
                                .opacity(0.15)
                                .blendMode(.multiply)
                        }
                    }
                    .frame(width: max(0, width * CGFloat(segment.duration / totalDuration)))
                    .offset(x: width * CGFloat(segment.startTime / totalDuration))
                    .padding(.vertical, 4)
                    .allowsHitTesting(false)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedSegmentId)
                    .contextMenu {
                        Section("Change Type") {
                            Button { onUpdateSegmentType?(segment.id, .performance) } label: {
                                Label("Performance", systemImage: "music.note")
                            }
                            Button { onUpdateSegmentType?(segment.id, .conversation) } label: {
                                Label("Conversation", systemImage: "bubble.left.and.bubble.right.fill")
                            }
                            Button { onUpdateSegmentType?(segment.id, .silence) } label: {
                                Label("Silence", systemImage: "zzz")
                            }
                        }
                        Section("Edit") {
                            Button { onMergeWithNext?(segment.id) } label: {
                                let mergeIcon = "rectangle.and.arrow.up.right.and.arrow.down.left.slash"
                                Label("Merge with Next", systemImage: mergeIcon)
                            }
                            .disabled(segment.id == segments.last?.id)
                        }
                    }
                }

                // 境界ハンドル
                ForEach(0 ..< max(0, segments.count - 1), id: \.self) { index in
                    let segment = segments[index]
                    ZStack {
                        let colors: [Color] = [
                            .clear,
                            .white.opacity(isHoveringBoundary == index ? 0.8 : 0.4),
                            .clear
                        ]
                        Rectangle()
                            .fill(LinearGradient(
                                colors: colors,
                                startPoint: .top,
                                endPoint: .bottom
                            ))
                            .frame(width: isHoveringBoundary == index ? 8 : 4)
                    }
                    .frame(width: 20)
                    .offset(x: width * CGFloat(segment.endTime / totalDuration) - 10)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let currentOffset = width * CGFloat(segment.endTime / totalDuration)
                                let newX = value.location.x + (currentOffset - 10)
                                let newTime = Double(newX / width) * totalDuration
                                onMoveBoundary?(index, newTime)
                            }
                    )
                    .onHover { inside in
                        isHoveringBoundary = inside ? index : nil
                        if inside {
                            NSCursor.resizeLeftRight.push()
                        } else {
                            NSCursor.pop()
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: isHoveringBoundary)
                }

                // 波形本体
                Path { path in
                    let height = geometry.size.height
                    let middle = height / 2
                    guard samples.count > 1 else { return }
                    let step = width / CGFloat(samples.count - 1)
                    path.move(to: CGPoint(x: 0, y: middle + CGFloat(samples[0].max) * middle))
                    for i in 1 ..< samples.count {
                        path.addLine(to: CGPoint(x: CGFloat(i) * step, y: middle + CGFloat(samples[i].max) * middle))
                    }
                    for i in (0 ..< samples.count).reversed() {
                        path.addLine(to: CGPoint(x: CGFloat(i) * step, y: middle + CGFloat(samples[i].min) * middle))
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.9), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: color.opacity(0.4), radius: 3, x: 0, y: 2)
                .allowsHitTesting(false)

                // Ghost Playhead (Hover feedback)
                if let hoverPos = hoverPosition {
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.3))
                        .frame(width: 1)
                        .offset(x: width * CGFloat(hoverPos))
                        .allowsHitTesting(false)
                }

                // 再生カーソル (Liquid Glass Glow)
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 1)
                        .shadow(color: .white, radius: 4)

                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: 2)
                        .shadow(color: Color.accentColor, radius: 2)
                }
                .offset(x: width * CGFloat(playbackPosition))
                .animation(.interactiveSpring(), value: playbackPosition)
            }
        }
    }

    private func selectSegment(at time: TimeInterval) {
        let hitSegment = segments.first { segment in
            segment.startTime <= time && time < segment.endTime
        }
        if let hitSegment = hitSegment {
            onSelectSegment?(hitSegment.id)
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
