import SwiftUI

/// All rectangles use the root GeometryReader's local coordinates. Its size is
/// already safe-area constrained; only the decorative canvas adds the insets back.
struct TableLayout {
    let canvas: CGRect
    let region: CGRect
    let safeRegion: CGRect
    let adaptive: Bool
    let wide: Bool
    let referenceHeight: CGFloat
    let occlusions: [CGRect]

    init(geometry: GeometryProxy, horizontalSizeClass: UserInterfaceSizeClass?) {
        let insets = geometry.safeAreaInsets
        canvas = CGRect(x: -insets.leading, y: -insets.top,
                        width: geometry.size.width + insets.leading + insets.trailing,
                        height: geometry.size.height + insets.top + insets.bottom)
        let safe = CGRect(origin: .zero, size: geometry.size)
        var available = canvas
        var holes: [CGRect] = []
        var hasDivision = false
        if #available(iOS 27.1, *) {
            let divisions = geometry.reservedRegions(kind: .division, options: .includeInactive)
            hasDivision = !divisions.isEmpty
            for division in divisions where division.isActive {
                // Keep the table, its hands, and actions together on one side.
                let margins = division.margins
                let fold = CGRect(x: division.frame.minX - margins.leading,
                                  y: division.frame.minY - margins.top,
                                  width: division.frame.width + margins.leading + margins.trailing,
                                  height: division.frame.height + margins.top + margins.bottom)
                available = Self.largestRegion(in: available, excluding: fold)
            }
            holes = geometry.reservedRegions(kind: .occlusion).map { region in
                let margins = region.margins
                return CGRect(x: region.frame.minX - margins.leading,
                              y: region.frame.minY - margins.top,
                              width: region.frame.width + margins.leading + margins.trailing,
                              height: region.frame.height + margins.top + margins.bottom)
            }
        }
        region = available
        safeRegion = available.intersection(safe)
        occlusions = holes
        adaptive = hasDivision || abs(insets.leading - insets.trailing) > 12
            || horizontalSizeClass == .regular || canvas.width >= 600
        wide = available.width >= 600
        referenceHeight = geometry.size.height
    }

    var sceneWidth: CGFloat { min(720, region.width) }
    var contentWidth: CGFloat { max(1, min(520, sceneWidth - 44)) }
    var toolbarFrame: CGRect {
        CGRect(x: safeRegion.midX - min(contentWidth, safeRegion.width - 44) / 2,
               y: safeRegion.minY + 8, width: max(1, min(contentWidth, safeRegion.width - 44)), height: 46)
    }

    /// Maximal unobstructed rectangle, preferring trailing/bottom on equal areas.
    private static func largestRegion(in rect: CGRect, excluding obstacle: CGRect) -> CGRect {
        let cut = rect.intersection(obstacle)
        guard !cut.isNull else { return rect }
        let candidates = [
            CGRect(x: rect.minX, y: rect.minY, width: max(0, cut.minX - rect.minX), height: rect.height),
            CGRect(x: cut.maxX, y: rect.minY, width: max(0, rect.maxX - cut.maxX), height: rect.height),
            CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(0, cut.minY - rect.minY)),
            CGRect(x: rect.minX, y: cut.maxY, width: rect.width, height: max(0, rect.maxY - cut.maxY))
        ]
        return candidates.enumerated().max {
            let a = $0.element.width * $0.element.height
            let b = $1.element.width * $1.element.height
            return a == b ? $0.offset < $1.offset : a < b
        }?.element ?? rect
    }

    func placement(playing: Bool, fieldHeight: CGFloat, controlsHeight: CGFloat) -> TablePlacement {
        // The complete composition can scroll on very short split/fold windows;
        // cards and touch targets retain their normal dimensions.
        let dealerSpace: CGFloat = region.height < 600 ? 360 : 220
        let minimumHeight = fieldHeight + controlsHeight + (playing ? dealerSpace : 340)
        let height = max(region.height, minimumHeight)
        let bottom = region.minY + height - max(28, canvas.maxY - safeRegion.maxY + 12)
        let controlsTop = bottom - controlsHeight
        let welcomeTop = contentWidth < 340
            ? controlsTop - SchoolChipButton.diameter - SchoolChipButton.startSpacing - fieldHeight - 16
            : region.minY + height * 0.51
        let fieldTop = playing ? controlsTop - 22 - fieldHeight : welcomeTop
        let railY = playing ? fieldTop - 14 : fieldTop - 24
        // Normalized artwork landmarks: upper rail at y=0.095; the broad
        // central felt ends before y=0.80. Scale uniformly and crop laterally.
        let tableHeight = max((bottom + 30 - railY) / 0.70, sceneWidth * 0.75)
        let tableFrame = CGRect(x: region.midX - tableHeight * (4 / 3.0) / 2,
                                y: railY - tableHeight * 0.095,
                                width: tableHeight * (4 / 3.0), height: tableHeight)
        // A larger portrait may extend behind the rail, but never lose its head
        // beyond the top edge. The Duo toolbar leaves the face unobstructed.
        let dealerHeight = height * (playing ? (wide ? 0.45 : 0.39) : 0.39)
        let dealerFrame = CGRect(x: region.midX - dealerHeight * (1200 / 1002.0) / 2,
                                 y: max(region.minY + 14, railY - dealerHeight * 0.93),
                                 width: dealerHeight * (1200 / 1002.0), height: dealerHeight)
        var fieldFrame = CGRect(x: region.midX - contentWidth / 2, y: fieldTop,
                                width: contentWidth, height: fieldHeight)
        var controlsFrame = CGRect(x: region.midX - contentWidth / 2, y: controlsTop,
                                   width: contentWidth, height: controlsHeight)
        for hole in occlusions {
            if fieldFrame.intersects(hole) { fieldFrame = Self.largestRegion(in: fieldFrame, excluding: hole) }
            if controlsFrame.intersects(hole) { controlsFrame = Self.largestRegion(in: controlsFrame, excluding: hole) }
        }
        return TablePlacement(height: height, table: tableFrame, dealer: dealerFrame,
                              field: fieldFrame, controls: controlsFrame, railY: railY)
    }
}

struct TablePlacement {
    let height: CGFloat
    let table: CGRect
    let dealer: CGRect
    let field: CGRect
    let controls: CGRect
    let railY: CGFloat
}

struct TableContentHeights: Equatable {
    var field: CGFloat = 290
    var controls: CGFloat = 128
}

struct TableContentHeightKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] { [:] }
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

extension View {
    func tableHeight(_ key: String) -> some View {
        background(GeometryReader { proxy in
            Color.clear.preference(key: TableContentHeightKey.self, value: [key: proxy.size.height])
        })
    }

    func tableFrame(_ rect: CGRect) -> some View {
        frame(width: rect.width, height: rect.height).position(x: rect.midX, y: rect.midY)
    }
}
