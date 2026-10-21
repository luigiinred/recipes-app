import SwiftUI

/// One bone's pose about its pivot: translate, rotate, shear, then scale.
struct BonePose: Equatable {
    var dx = 0.0, dy = 0.0
    /// Degrees, clockwise.
    var rot = 0.0
    var sx = 1.0, sy = 1.0
    /// Horizontal shear in degrees.
    var skx = 0.0
    /// Replaces the rig's pivot, to squash about the feet instead of the bone's own origin.
    var pivot: CGPoint?

    func matrix(pivot rigPivot: CGPoint) -> CGAffineTransform {
        let p = pivot ?? rigPivot
        var m = CGAffineTransform(translationX: dx, y: dy)
        m = mul(m, CGAffineTransform(translationX: p.x, y: p.y))
        m = mul(m, CGAffineTransform(rotationAngle: rot * .pi / 180))
        m = mul(m, CGAffineTransform(a: 1, b: 0, c: tan(skx * .pi / 180), d: 1, tx: 0, ty: 0))
        m = mul(m, CGAffineTransform(scaleX: sx, y: sy))
        return mul(m, CGAffineTransform(translationX: -p.x, y: -p.y))
    }
}

typealias Pose = [String: BonePose]

/// `a` then `b` reads right to left: the result applies `b` to a point first.
func mul(_ a: CGAffineTransform, _ b: CGAffineTransform) -> CGAffineTransform { b.concatenating(a) }

/// A rigged SVG: paths in nested groups, where groups marked `data-bone` can be posed.
/// Only the subset the mascot art uses is parsed: absolute M L C Q Z paths, ellipses, circles,
/// groups, solid fills, and linear or radial gradients in bounding-box units.
final class SVGRig {
    enum Paint {
        case color(Color)
        case gradient(String)
    }

    struct Gradient {
        var isLinear: Bool
        /// Linear: x1 y1 x2 y2. Radial: cx cy r.
        var geometry: [CGFloat]
        var stops: [SwiftUI.Gradient.Stop]
    }

    final class Node {
        var id: String?
        var isBone = false
        var parentBone: String?
        var pivot = CGPoint.zero
        var children: [Node] = []
        var path: Path?
        var fill: Paint?
        var stroke: Paint?
        var strokeWidth: CGFloat = 0
        var opacity: CGFloat = 1
        var hidden = false
        fileprivate(set) lazy var bounds: CGRect = path?.cgPath.boundingBoxOfPath ?? .zero
    }

    let root: Node
    let viewBox: CGRect
    private(set) var gradients: [String: Gradient]
    private let bones: [String: Node]

    init(root: Node, viewBox: CGRect, gradients: [String: Gradient]) {
        self.root = root
        self.viewBox = viewBox
        self.gradients = gradients
        var found: [String: Node] = [:]
        func walk(_ node: Node) {
            if node.isBone, let id = node.id { found[id] = node }
            node.children.forEach(walk)
        }
        walk(root)
        bones = found
    }

    func pivot(of bone: String) -> CGPoint { bones[bone]?.pivot ?? .zero }
    func parent(of bone: String) -> String? { bones[bone]?.parentBone.flatMap { $0.isEmpty ? nil : $0 } }
    func hasBone(_ bone: String) -> Bool { bones[bone] != nil }

    /// The matrix that takes a point in a bone's rest pose to where the bone's ancestors and the bone itself put it.
    func matrix(of bone: String, pose: Pose) -> CGAffineTransform {
        var chain: [String] = []
        var current: String? = bone
        while let id = current { chain.append(id); current = parent(of: id) }
        return chain.reversed().reduce(CGAffineTransform.identity) { m, id in
            mul(m, (pose[id] ?? BonePose()).matrix(pivot: pivot(of: id)))
        }
    }

    // MARK: Loading

    private static var cache: [String: SVGRig] = [:]

    static func named(_ name: String) -> SVGRig {
        if let hit = cache[name] { return hit }
        let rig = Bundle.main.url(forResource: name, withExtension: "svg")
            .flatMap { try? Data(contentsOf: $0) }
            .flatMap(SVGRigParser.parse)
            ?? SVGRig(root: Node(), viewBox: CGRect(x: 0, y: 0, width: 1, height: 1), gradients: [:])
        assert(rig.root.children.isEmpty == false, "Missing mascot art: \(name).svg")
        cache[name] = rig
        return rig
    }

    // MARK: Drawing

    /// A bone's ancestors posed, with only that bone's subtree drawn. For putting a hand above something drawn later.
    func drawBone(_ bone: String, in context: inout GraphicsContext, pose: Pose, visibility: [String: Bool] = [:], opacity: CGFloat = 1) {
        var ancestors: [String] = []
        var current = parent(of: bone)
        while let id = current { ancestors.append(id); current = parent(of: id) }
        var ctx = context
        for id in ancestors.reversed() {
            ctx.concatenate((pose[id] ?? BonePose()).matrix(pivot: pivot(of: id)))
        }
        guard let node = bones[bone] else { return }
        draw(node, in: ctx, pose: pose, visibility: visibility, opacity: opacity, attachments: [:])
    }

    /// Something drawn inside a bone, behind its own art, such as a wok in a hand.
    struct Attachment {
        var rig: SVGRig
        var base: CGAffineTransform
        var pose: Pose = [:]
    }

    func draw(in context: inout GraphicsContext, pose: Pose, visibility: [String: Bool] = [:], opacity: CGFloat = 1, attachments: [String: Attachment] = [:]) {
        draw(root, in: context, pose: pose, visibility: visibility, opacity: opacity, attachments: attachments)
    }

    private func draw(_ node: Node, in parent: GraphicsContext, pose: Pose, visibility: [String: Bool], opacity: CGFloat, attachments: [String: Attachment]) {
        if let id = node.id, visibility[id] == false { return }
        if node.hidden, node.id.flatMap({ visibility[$0] }) != true { return }
        var ctx = parent
        if node.isBone, let id = node.id {
            ctx.concatenate((pose[id] ?? BonePose()).matrix(pivot: node.pivot))
            if let attachment = attachments[id] {
                var inner = ctx
                inner.concatenate(attachment.base)
                attachment.rig.draw(in: &inner, pose: attachment.pose, visibility: visibility, opacity: opacity * node.opacity)
            }
        }
        let alpha = opacity * node.opacity
        if let path = node.path {
            ctx.opacity = alpha
            if let fill = node.fill { paint(path, node: node, with: fill, in: &ctx, stroke: nil) }
            if let stroke = node.stroke, node.strokeWidth > 0 { paint(path, node: node, with: stroke, in: &ctx, stroke: node.strokeWidth) }
        }
        for child in node.children {
            draw(child, in: ctx, pose: pose, visibility: visibility, opacity: alpha, attachments: attachments)
        }
    }

    private func paint(_ path: Path, node: Node, with paint: Paint, in ctx: inout GraphicsContext, stroke width: CGFloat?) {
        let style = StrokeStyle(lineWidth: width ?? 0, lineCap: .round, lineJoin: .round)
        switch paint {
        case .color(let color):
            if let width { ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)) }
            else { ctx.fill(path, with: .color(color)) }
        case .gradient(let id):
            guard let gradient = gradients[id] else { return }
            // Gradients are in bounding-box units, so draw in a space where the box is the unit square.
            let box = node.bounds
            guard box.width > 0, box.height > 0 else { return }
            let toUnit = CGAffineTransform(translationX: box.minX, y: box.minY).scaledBy(x: box.width, y: box.height)
            var inner = ctx
            inner.concatenate(toUnit)
            let unitPath = path.applying(toUnit.inverted())
            let shading: GraphicsContext.Shading
            let g = SwiftUI.Gradient(stops: gradient.stops)
            if gradient.isLinear {
                shading = .linearGradient(g, startPoint: CGPoint(x: gradient.geometry[0], y: gradient.geometry[1]), endPoint: CGPoint(x: gradient.geometry[2], y: gradient.geometry[3]))
            } else {
                shading = .radialGradient(g, center: CGPoint(x: gradient.geometry[0], y: gradient.geometry[1]), startRadius: 0, endRadius: gradient.geometry[2])
            }
            if width != nil {
                inner.stroke(unitPath, with: shading, style: style)
            } else {
                inner.fill(unitPath, with: shading)
            }
        }
    }
}

// MARK: - Parsing

private final class SVGRigParser: NSObject, XMLParserDelegate {
    struct Style {
        var fill: SVGRig.Paint? = .color(.black)
        var stroke: SVGRig.Paint?
        var strokeWidth: CGFloat = 1
    }

    private let rootNode = SVGRig.Node()
    private var stack: [(node: SVGRig.Node, style: Style)] = []
    private var viewBox = CGRect(x: 0, y: 0, width: 1, height: 1)
    private var gradients: [String: SVGRig.Gradient] = [:]
    private var gradientID: String?
    private var gradient: SVGRig.Gradient?

    static func parse(_ data: Data) -> SVGRig? {
        let delegate = SVGRigParser()
        delegate.stack = [(delegate.rootNode, Style())]
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return SVGRig(root: delegate.rootNode, viewBox: delegate.viewBox, gradients: delegate.gradients)
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String]) {
        func number(_ key: String, _ fallback: CGFloat = 0) -> CGFloat { a[key].flatMap { Double($0) }.map { CGFloat($0) } ?? fallback }
        switch name {
        case "svg":
            let v = (a["viewBox"] ?? "").split(whereSeparator: { $0 == " " || $0 == "," }).compactMap { Double($0) }
            if v.count == 4 { viewBox = CGRect(x: v[0], y: v[1], width: v[2], height: v[3]) }
        case "linearGradient", "radialGradient":
            gradientID = a["id"]
            gradient = name == "linearGradient"
                ? SVGRig.Gradient(isLinear: true, geometry: [number("x1"), number("y1"), number("x2", 1), number("y2")], stops: [])
                : SVGRig.Gradient(isLinear: false, geometry: [number("cx", 0.5), number("cy", 0.5), number("r", 0.5)], stops: [])
        case "stop":
            let offset = number("offset")
            if let color = Self.color(a["stop-color"] ?? "#000000") { gradient?.stops.append(.init(color: color, location: offset)) }
        case "g", "path", "ellipse", "circle":
            var style = stack.last?.style ?? Style()
            if let fill = a["fill"] { style.fill = Self.paint(fill) }
            if let stroke = a["stroke"] { style.stroke = Self.paint(stroke) }
            if let width = a["stroke-width"].flatMap({ Double($0) }) { style.strokeWidth = CGFloat(width) }
            let node = SVGRig.Node()
            node.id = a["id"]
            node.opacity = number("opacity", 1)
            node.hidden = a["display"] == "none"
            if a["data-bone"] != nil {
                node.isBone = true
                node.parentBone = a["data-parent"]
                let p = (a["data-pivot"] ?? "").split(separator: " ").compactMap { Double($0) }
                if p.count == 2 { node.pivot = CGPoint(x: p[0], y: p[1]) }
            }
            switch name {
            case "path": node.path = Self.path(a["d"] ?? "")
            case "ellipse": node.path = Path(ellipseIn: CGRect(x: number("cx") - number("rx"), y: number("cy") - number("ry"), width: 2 * number("rx"), height: 2 * number("ry")))
            case "circle": node.path = Path(ellipseIn: CGRect(x: number("cx") - number("r"), y: number("cy") - number("r"), width: 2 * number("r"), height: 2 * number("r")))
            default: break
            }
            if node.path != nil {
                node.fill = style.fill
                node.stroke = style.stroke
                node.strokeWidth = style.strokeWidth
            }
            stack.last?.node.children.append(node)
            stack.append((node, style))
        default: break
        }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "linearGradient", "radialGradient":
            if let id = gradientID, let gradient { gradients[id] = gradient }
            gradientID = nil; gradient = nil
        case "g", "path", "ellipse", "circle":
            stack.removeLast()
        default: break
        }
    }

    static func paint(_ value: String) -> SVGRig.Paint? {
        if value == "none" { return nil }
        if value.hasPrefix("url(#"), let end = value.firstIndex(of: ")") {
            return .gradient(String(value[value.index(value.startIndex, offsetBy: 5)..<end]))
        }
        return color(value).map { .color($0) }
    }

    static func color(_ hex: String) -> Color? {
        var h = hex.trimmingCharacters(in: .whitespaces)
        guard h.hasPrefix("#") else { return nil }
        h.removeFirst()
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        guard h.count == 6, let value = UInt32(h, radix: 16) else { return nil }
        return Color(.sRGB, red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }

    /// Absolute M, L, C, Q and Z only, which is all the art uses.
    static func path(_ d: String) -> Path {
        var spaced = ""
        for ch in d {
            if "MLCQZ".contains(ch) { spaced += " \(ch) " } else if ch == "," { spaced += " " } else { spaced.append(ch) }
        }
        let tokens = spaced.split(separator: " ").map(String.init)
        var path = Path()
        var i = 0
        func next() -> CGFloat { defer { i += 1 }; return i < tokens.count ? CGFloat(Double(tokens[i]) ?? 0) : 0 }
        func point() -> CGPoint { let x = next(); return CGPoint(x: x, y: next()) }
        while i < tokens.count {
            let command = tokens[i]; i += 1
            switch command {
            case "M": path.move(to: point())
            case "L": path.addLine(to: point())
            case "C": let c1 = point(), c2 = point(), end = point(); path.addCurve(to: end, control1: c1, control2: c2)
            case "Q": let c = point(), end = point(); path.addQuadCurve(to: end, control: c)
            case "Z": path.closeSubpath()
            default: break
            }
        }
        return path
    }
}
