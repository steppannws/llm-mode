import SwiftUI
import AppKit

/// rounded tile used for every block in the panel
struct StatCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }
}

private let modelGradient = LinearGradient(colors: [.blue, .indigo], startPoint: .leading, endPoint: .trailing)

struct RingGauge: View {
    let fraction: Double
    var body: some View {
        let f = min(max(fraction, 0), 1)
        ZStack {
            Circle().stroke(.quaternary, lineWidth: 7)
            Circle().trim(from: 0, to: f)
                .stroke(modelGradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((f * 100).rounded()))%").font(.caption.weight(.semibold)).monospacedDigit()
        }
        .frame(width: 56, height: 56)
    }
}

/// unified memory split into model / other apps / macOS reserve; the rest is free
struct MemoryBar: View {
    let mem: Status.Mem
    var body: some View {
        let s = mem.segments
        let total = Double(max(mem.totalMb, 1))
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Unified memory · \(Format.gb(mem.totalMb)) GB").foregroundStyle(.secondary)
                Spacer()
                Text("\(Format.gb(s.free)) GB free")
            }
            .font(.caption)
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle().fill(modelGradient).frame(width: geo.size.width * Double(s.model) / total)
                    Rectangle().fill(.orange).frame(width: geo.size.width * Double(s.other) / total)
                    Rectangle().fill(.gray).frame(width: geo.size.width * Double(s.reserve) / total)
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 10)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            HStack(spacing: 10) {
                legend(.blue, "Model \(Format.gb(s.model))")
                legend(.orange, "Other \(Format.gb(s.other))")
                legend(.gray, "macOS \(Format.gb(s.reserve))")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(text)
        }
    }
}

/// monospaced command with a copy button that briefly turns into a checkmark
struct CopyRow: View {
    let label: String
    let text: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                } label: {
                    if copied { Text("Copied ✓").font(.caption) } else { Image(systemName: "doc.on.doc") }
                }
                .buttonStyle(.borderless)
                .help("Copy")
            }
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.head)
                .textSelection(.enabled)
        }
    }
}
