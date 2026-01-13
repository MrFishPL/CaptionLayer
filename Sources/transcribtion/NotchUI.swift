import AppKit

final class NotchPanel: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        setFrame(frame, display: true)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class NotchView: NSView {
    private let maskLayer = CAShapeLayer()
    private let textView: NSTextView
    private let scrollView: NSScrollView
    private let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .semibold)

    override init(frame frameRect: NSRect) {
        textView = NSTextView(frame: .zero)
        scrollView = NSScrollView(frame: .zero)
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.mask = maskLayer

        textView.font = font
        textView.textColor = NSColor.white.withAlphaComponent(0.9)
        textView.alignment = .center
        textView.isEditable = false
        textView.isSelectable = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.lineBreakMode = .byWordWrapping
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.string = "Listening..."

        scrollView.drawsBackground = false
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.documentView = textView
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(scrollView)
        autoresizingMask = [.width, .height]

        let lineHeight = font.ascender - font.descender + font.leading
        let textHeight = ceil(lineHeight * AppConfig.visibleLines)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -AppConfig.bottomPadding),
            scrollView.heightAnchor.constraint(equalToConstant: textHeight),
            scrollView.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: AppConfig.topDeadArea),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        updateTextLayout()
        updateMaskPath()
    }

    func setText(_ text: String) {
        textView.string = text
        updateTextLayout()
    }

    private func updateTextLayout() {
        let width = scrollView.bounds.width
        guard width > 0 else { return }
        textView.textContainer?.size = NSSize(width: width, height: .greatestFiniteMagnitude)
        textView.minSize = NSSize(width: width, height: 0)
        textView.maxSize = NSSize(width: width, height: .greatestFiniteMagnitude)

        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.frame = NSRect(x: 0, y: 0, width: width, height: textView.frame.height)
        textView.sizeToFit()

        let visibleHeight = ceil((font.ascender - font.descender + font.leading) * AppConfig.visibleLines)
        if let container = textView.textContainer,
           let layout = textView.layoutManager {
            layout.ensureLayout(for: container)
            let contentHeight = layout.usedRect(for: container).height
            let inset = max(0, (visibleHeight - contentHeight) / 2)
            textView.textContainerInset = NSSize(width: 0, height: inset)
            textView.frame = NSRect(x: 0, y: 0, width: width, height: max(visibleHeight, contentHeight + inset * 2))
        }

        textView.scrollToEndOfDocument(nil)
    }

    private func updateMaskPath() {
        let rect = bounds
        let bottomRadius: CGFloat = 14
        let bottomK: CGFloat = 0.55
        let path = CGMutablePath()

        // Top is flat with square corners, bottom is rounded.
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + bottomRadius))
        path.addCurve(
            to: CGPoint(x: rect.maxX - bottomRadius, y: rect.minY),
            control1: CGPoint(x: rect.maxX, y: rect.minY + bottomRadius * (1 - bottomK)),
            control2: CGPoint(x: rect.maxX - bottomRadius * (1 - bottomK), y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + bottomRadius, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + bottomRadius),
            control1: CGPoint(x: rect.minX + bottomRadius * (1 - bottomK), y: rect.minY),
            control2: CGPoint(x: rect.minX, y: rect.minY + bottomRadius * (1 - bottomK))
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        maskLayer.path = path
    }
}
