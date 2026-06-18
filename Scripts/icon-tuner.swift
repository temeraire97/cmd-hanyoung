#!/usr/bin/env swift
// icon-tuner.swift
// 실시간 아이콘 튜너 GUI — make-icon.swift 렌더 로직 파라미터화 버전
// 실행: swift Scripts/icon-tuner.swift

import AppKit
import SwiftUI

// ─────────────────────────────────────────
// MARK: - SF Symbol ink 측정 상수 (고정값, 측정치라 파라미터 아님)
// ─────────────────────────────────────────

// keyboard (semibold, 실측 frac)
let KB_LEFT_FRAC:        CGFloat = 0.0823
let KB_RIGHT_FRAC:       CGFloat = 0.0831
let KB_TOP_FRAC:         CGFloat = 0.0894
let KB_BOTTOM_FRAC:      CGFloat = 0.0894
let KB_INK_WIDTH_FRAC:   CGFloat = 0.8346
let KB_INK_HEIGHT_FRAC:  CGFloat = 0.8212
let KB_ASPECT:           CGFloat = 1.5364  // draw-rect width / height

// command (⌘) (semibold, 실측 frac)
let CMD_LEFT_FRAC:       CGFloat = 0.1044
let CMD_RIGHT_FRAC:      CGFloat = 0.1044
let CMD_TOP_FRAC:        CGFloat = 0.0787
let CMD_BOTTOM_FRAC:     CGFloat = 0.0787
let CMD_INK_WIDTH_FRAC:  CGFloat = 0.7911
let CMD_INK_HEIGHT_FRAC: CGFloat = 0.8425
let CMD_ASPECT:          CGFloat = 1.0664

// ─────────────────────────────────────────
// MARK: - IconParams 구조체 (조정 가능한 파라미터)
// ─────────────────────────────────────────

struct IconParams {
    // 캔버스 고정
    var canvas: CGFloat        = 1024.0

    // 라운드렉트
    var squirclePaddingRatio: CGFloat = 100.0 / 1024.0  // macOS 그리드: 100/1024 ≈ 0.09766
    var cornerRatio: CGFloat   = 0.225      // corner_radius / squircle_size

    // 글리프 비율
    var keyboardSizeRatio: CGFloat = 0.5562  // keyboard draw-rect 폭 / squircle
    var cmdSizeRatio: CGFloat      = 0.4264  // command draw-rect 폭 / squircle
    var glyphGap: CGFloat          = 64.0    // px — keyboard↔command ink gap

    // 그림자
    var shadowAlpha:   CGFloat = 0.25
    var shadowBlur:    CGFloat = 6.0
    var shadowOffsetY: CGFloat = -3.0  // 음수 = 아래

    // 그라데이션 각도 (degrees, -90 ~ 0)
    // 현재 make-icon.swift는 좌상→우하 대각선(-45°)
    var gradientAngle: CGFloat = -45.0

    // 그라데이션 3색
    var violetColor: NSColor = NSColor(srgbRed: 0.616, green: 0.361, blue: 0.965, alpha: 1.0)  // #9D5CF6
    var cyanColor:   NSColor = NSColor(srgbRed: 0.024, green: 0.714, blue: 0.831, alpha: 1.0)  // #06B6D4
    var darkColor:   NSColor = NSColor(srgbRed: 0.01,  green: 0.44,  blue: 0.54,  alpha: 1.0)  // 하단 볼륨감

    // 글리프별 독립 위치 오프셋 (squircle-local px, 기본 0)
    // 양수 Y = 화면상 아래 (draw 좌표엔 -OFFSET_Y 반영)
    var kbOffsetX:  CGFloat = 0.0   // keyboard 가로 nudge (양수=오른쪽)
    var kbOffsetY:  CGFloat = 0.0   // keyboard 세로 nudge (양수=아래)
    var cmdOffsetX: CGFloat = 0.0   // command  가로 nudge (양수=오른쪽)
    var cmdOffsetY: CGFloat = 0.0   // command  세로 nudge (양수=아래)
}

// ─────────────────────────────────────────
// MARK: - 렌더 함수 (make-icon.swift 동일 로직, 파라미터화)
// ─────────────────────────────────────────

func renderIcon(params: IconParams) -> NSImage {
    let CANVAS = params.canvas

    // squircle 크기 & 패딩
    let PADDING        = CANVAS * params.squirclePaddingRatio
    let SQUIRCLE_SIZE  = CANVAS - PADDING * 2
    let CORNER_RADIUS  = SQUIRCLE_SIZE * params.cornerRatio

    // 글리프 draw-rect 크기
    let KB_DRAW_W  = params.keyboardSizeRatio * SQUIRCLE_SIZE
    let KB_DRAW_H  = KB_DRAW_W / KB_ASPECT

    let CMD_DRAW_W = params.cmdSizeRatio * SQUIRCLE_SIZE
    let CMD_DRAW_H = CMD_DRAW_W / CMD_ASPECT

    // ink bbox 크기
    let KB_INK_W   = KB_INK_WIDTH_FRAC  * KB_DRAW_W
    let KB_INK_H   = KB_INK_HEIGHT_FRAC * KB_DRAW_H

    let CMD_INK_W  = CMD_INK_WIDTH_FRAC  * CMD_DRAW_W
    let CMD_INK_H  = CMD_INK_HEIGHT_FRAC * CMD_DRAW_H

    // union bbox
    let GLYPH_GAP  = params.glyphGap
    let UNION_W    = KB_INK_W + GLYPH_GAP + CMD_INK_W
    let UNION_H    = KB_INK_H + GLYPH_GAP + CMD_INK_H

    // squircle 원점 (CG 절대 좌표, y-up)
    let SQ_CX = PADDING + SQUIRCLE_SIZE / 2.0
    let SQ_CY = PADDING + SQUIRCLE_SIZE / 2.0

    // keyboard ink top-left (CG 절대) — union bbox 정중앙 배치
    let KB_INK_ABS_X   = SQ_CX - UNION_W / 2.0
    let KB_INK_ABS_TOP = SQ_CY + UNION_H / 2.0

    // keyboard draw-rect origin (CG y-up)
    let KB_DRAW_X   = KB_INK_ABS_X   - KB_LEFT_FRAC * KB_DRAW_W
    let KB_DRAW_TOP = KB_INK_ABS_TOP + KB_TOP_FRAC  * KB_DRAW_H
    let KB_DRAW_Y   = KB_DRAW_TOP    - KB_DRAW_H

    // command ink top-left (CG 절대)
    let CMD_INK_ABS_X   = KB_INK_ABS_X   + KB_INK_W + GLYPH_GAP
    let CMD_INK_ABS_TOP = KB_INK_ABS_TOP - KB_INK_H - GLYPH_GAP

    // command draw-rect origin (CG y-up)
    let CMD_DRAW_X   = CMD_INK_ABS_X   - CMD_LEFT_FRAC * CMD_DRAW_W
    let CMD_DRAW_TOP = CMD_INK_ABS_TOP + CMD_TOP_FRAC  * CMD_DRAW_H
    let CMD_DRAW_Y   = CMD_DRAW_TOP    - CMD_DRAW_H

    // ── 비트맵 생성
    let size = NSSize(width: CANVAS, height: CANVAS)
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(CANVAS), pixelsHigh: Int(CANVAS),
        bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0, bitsPerPixel: 32
    ) else { fatalError("NSBitmapImageRep 생성 실패") }

    guard let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(
              data: bitmap.bitmapData,
              width: Int(CANVAS), height: Int(CANVAS),
              bitsPerComponent: 8, bytesPerRow: bitmap.bytesPerRow,
              space: srgbSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else { fatalError("CGContext 생성 실패") }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // ── 0. 투명 배경
    ctx.clear(CGRect(x: 0, y: 0, width: CANVAS, height: CANVAS))

    // ── 1. squircle path
    let squircleRect = CGRect(x: PADDING, y: PADDING, width: SQUIRCLE_SIZE, height: SQUIRCLE_SIZE)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: CORNER_RADIUS, cornerHeight: CORNER_RADIUS, transform: nil)

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        fatalError("sRGB 색공간 생성 실패")
    }

    // ── 2. 배경 그라데이션 (gradientAngle 기반 방향 계산)
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let violetCG = params.violetColor.cgColor
    let cyanCG   = params.cyanColor.cgColor
    let darkCG   = params.darkColor.cgColor

    let gradColors = [violetCG, cyanCG, darkCG] as CFArray
    let gradLocs: [CGFloat] = [0.0, 0.72, 1.0]
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: gradLocs) else {
        fatalError("그라데이션 생성 실패")
    }

    // gradientAngle: 0° = 좌→우, -90° = 위→아래, -45° = 좌상→우하
    // startPoint를 angle 방향 반대 끝, endPoint를 angle 방향 끝으로 설정
    let cx = PADDING + SQUIRCLE_SIZE / 2
    let cy = PADDING + SQUIRCLE_SIZE / 2
    let r  = SQUIRCLE_SIZE / 2 * 1.42  // 대각선 커버용 반지름
    let rad = params.gradientAngle * CGFloat.pi / 180.0
    let gradStart = CGPoint(x: cx - r * cos(rad), y: cy - r * sin(rad))
    let gradEnd   = CGPoint(x: cx + r * cos(rad), y: cy + r * sin(rad))

    ctx.drawLinearGradient(gradient, start: gradStart, end: gradEnd,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // ── 3. NSGraphicsContext 래핑 (flipped: false = y-up)
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)

    // 그림자 헬퍼
    func makeShadow() -> NSShadow {
        let s = NSShadow()
        s.shadowOffset     = NSSize(width: 0, height: params.shadowOffsetY)
        s.shadowBlurRadius = params.shadowBlur
        s.shadowColor      = NSColor(white: 0, alpha: params.shadowAlpha)
        return s
    }

    // ── 4. keyboard 글리프 (좌상단)
    let kbPointSize = KB_DRAW_W * 0.72

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    if let kbImage = NSImage(systemSymbolName: "keyboard", accessibilityDescription: nil) {
        let kbConfig = NSImage.SymbolConfiguration(pointSize: kbPointSize, weight: .semibold)
        var kbFinal  = kbImage.withSymbolConfiguration(kbConfig) ?? kbImage
        if #available(macOS 12.0, *) {
            let c = NSImage.SymbolConfiguration(paletteColors: [.white])
            kbFinal = kbFinal.withSymbolConfiguration(c) ?? kbFinal
        }
        let nat   = kbFinal.size
        let scale = KB_DRAW_W / nat.width
        let drawW = nat.width  * scale
        let drawH = nat.height * scale
        makeShadow().set()
        // kbOffsetX/Y: 양수=오른쪽/아래. y-up이므로 Y는 부호 반전(-).
        kbFinal.draw(
            in: NSRect(x: KB_DRAW_X + params.kbOffsetX, y: KB_DRAW_Y - params.kbOffsetY, width: drawW, height: drawH),
            from: .zero, operation: .sourceOver, fraction: 1.0
        )
        NSShadow().set()
    }
    NSGraphicsContext.restoreGraphicsState()

    // ── 5. command(⌘) 글리프 (우하단)
    let cmdPointSize = CMD_DRAW_W * 0.72

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = nsCtx

    if let cmdImage = NSImage(systemSymbolName: "command", accessibilityDescription: nil) {
        let cmdConfig = NSImage.SymbolConfiguration(pointSize: cmdPointSize, weight: .semibold)
        var cmdFinal  = cmdImage.withSymbolConfiguration(cmdConfig) ?? cmdImage
        if #available(macOS 12.0, *) {
            let c = NSImage.SymbolConfiguration(paletteColors: [.white])
            cmdFinal = cmdFinal.withSymbolConfiguration(c) ?? cmdFinal
        }
        let nat   = cmdFinal.size
        let scale = CMD_DRAW_W / nat.width
        let drawW = nat.width  * scale
        let drawH = nat.height * scale
        makeShadow().set()
        // cmdOffsetX/Y: 양수=오른쪽/아래. y-up이므로 Y는 부호 반전(-).
        cmdFinal.draw(
            in: NSRect(x: CMD_DRAW_X + params.cmdOffsetX, y: CMD_DRAW_Y - params.cmdOffsetY, width: drawW, height: drawH),
            from: .zero, operation: .sourceOver, fraction: 1.0
        )
        NSShadow().set()
    }
    NSGraphicsContext.restoreGraphicsState()

    // ── 6. CGContext → NSImage
    guard let cgImage = ctx.makeImage() else { fatalError("CGImage 변환 실패") }
    let finalBitmap = NSBitmapImageRep(cgImage: cgImage)
    let image = NSImage(size: size)
    image.addRepresentation(finalBitmap)
    return image
}

// ─────────────────────────────────────────
// MARK: - icns 내보내기 (sips + iconutil 인라인 실행)
// ─────────────────────────────────────────

func buildIcnsFile(from pngPath: String, outputPath: String) throws {
    // 임시 iconset 디렉터리 생성
    let tmpDir = NSTemporaryDirectory() + "AppIcon.iconset"
    try? FileManager.default.removeItem(atPath: tmpDir)
    try FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)

    // make-icon.sh 동일 사이즈 목록
    let sizes: [(size: Int, scale: Int, suffix: String)] = [
        (16,  1, "icon_16x16"),
        (32,  2, "icon_16x16@2x"),
        (32,  1, "icon_32x32"),
        (64,  2, "icon_32x32@2x"),
        (128, 1, "icon_128x128"),
        (256, 2, "icon_128x128@2x"),
        (256, 1, "icon_256x256"),
        (512, 2, "icon_256x256@2x"),
        (512, 1, "icon_512x512"),
        (1024,2, "icon_512x512@2x"),
    ]

    for entry in sizes {
        let outFile = "\(tmpDir)/\(entry.suffix).png"
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/sips")
        proc.arguments = ["-z", "\(entry.size)", "\(entry.size)", pngPath, "--out", outFile]
        try proc.run()
        proc.waitUntilExit()
    }

    // iconutil 실행
    let iconutil = Process()
    iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    iconutil.arguments = ["-c", "icns", tmpDir, "-o", outputPath]
    try iconutil.run()
    iconutil.waitUntilExit()

    // 임시 디렉터리 정리
    try? FileManager.default.removeItem(atPath: tmpDir)
}

// ─────────────────────────────────────────
// MARK: - AppKit 컨트롤 뷰 (NSView 기반)
// ─────────────────────────────────────────

// 슬라이더 + 라벨 한 행을 만드는 헬퍼
func makeSliderRow(
    label: String,
    minVal: Double, maxVal: Double, current: Double,
    target: AnyObject, action: Selector,
    tag: Int
) -> (row: NSView, slider: NSSlider, valueLabel: NSTextField) {
    let row = NSView()
    row.translatesAutoresizingMaskIntoConstraints = false

    // 이름 라벨
    let nameLabel = NSTextField(labelWithString: label)
    nameLabel.translatesAutoresizingMaskIntoConstraints = false
    nameLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    nameLabel.alignment = .right
    nameLabel.lineBreakMode = .byTruncatingTail

    // 슬라이더
    let slider = NSSlider()
    slider.translatesAutoresizingMaskIntoConstraints = false
    slider.minValue = minVal
    slider.maxValue = maxVal
    slider.doubleValue = current
    slider.target = target
    slider.action = action
    slider.tag = tag
    slider.isContinuous = true

    // 수치 직접입력 필드 (편집 가능 NSTextField)
    let valueLabel = NSTextField()
    valueLabel.translatesAutoresizingMaskIntoConstraints = false
    valueLabel.stringValue = String(format: "%.4f", current)
    valueLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
    valueLabel.alignment = .right
    valueLabel.isBordered = true
    valueLabel.isEditable = true
    valueLabel.isBezeled = true
    valueLabel.bezelStyle = .squareBezel
    valueLabel.usesSingleLineMode = true
    valueLabel.tag = tag   // 슬라이더와 동일 tag → 핸들러에서 식별
    valueLabel.setContentHuggingPriority(.required, for: .horizontal)
    valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

    row.addSubview(nameLabel)
    row.addSubview(slider)
    row.addSubview(valueLabel)

    NSLayoutConstraint.activate([
        nameLabel.leadingAnchor.constraint(equalTo: row.leadingAnchor),
        nameLabel.widthAnchor.constraint(equalToConstant: 130),
        nameLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

        slider.leadingAnchor.constraint(equalTo: nameLabel.trailingAnchor, constant: 8),
        slider.trailingAnchor.constraint(equalTo: valueLabel.leadingAnchor, constant: -8),
        slider.centerYAnchor.constraint(equalTo: row.centerYAnchor),

        valueLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor),
        valueLabel.widthAnchor.constraint(equalToConstant: 70),
        valueLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),

        row.heightAnchor.constraint(equalToConstant: 26),
    ])

    return (row, slider, valueLabel)
}

// ─────────────────────────────────────────
// MARK: - TunerViewController
// ─────────────────────────────────────────

class TunerViewController: NSViewController {
    var params = IconParams()

    // 미리보기 이미지 뷰
    var previewView:      NSImageView!
    var previewSmallView: NSImageView!
    var statusLabel:      NSTextField!

    // 슬라이더 참조 (tag로 구분)
    enum Tag: Int {
        case keyboardSizeRatio = 1
        case cmdSizeRatio      = 2
        case glyphGap          = 3
        case cornerRatio       = 4
        case shadowAlpha       = 5
        case gradientAngle     = 6
        case squirclePadding   = 7
        case shadowBlur        = 8
        case shadowOffsetY     = 9
        case kbOffsetX         = 10
        case kbOffsetY         = 11
        case cmdOffsetX        = 12
        case cmdOffsetY        = 13
    }

    var valueLabels: [Int: NSTextField] = [:]
    var sliders:     [Int: NSSlider]    = [:]   // tag → 슬라이더 (필드 커밋 시 범위 참조)

    // repo 루트 경로 (스크립트 위치 기준)
    var repoRoot: URL = {
        let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        return scriptDir.deletingLastPathComponent()
    }()

    override func loadView() {
        // 기본 창 크기 800×600
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        self.view.wantsLayer = true
        self.view.autoresizingMask = [.width, .height]  // 창 리사이즈 추적
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        rerender()
    }

    // ── UI 구성
    func setupUI() {
        let contentView = self.view

        // ── 좌측: 미리보기 영역
        let previewPanel = NSView()
        previewPanel.translatesAutoresizingMaskIntoConstraints = false
        previewPanel.wantsLayer = true
        previewPanel.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        contentView.addSubview(previewPanel)

        // 체커보드 배경 (투명도 확인)
        let checker = CheckerboardView()
        checker.translatesAutoresizingMaskIntoConstraints = false
        previewPanel.addSubview(checker)

        // 메인 미리보기 — 창 크기에 비례 축소/확대
        previewView = NSImageView()
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.imageScaling = .scaleProportionallyUpOrDown  // 창 축소 시 프리뷰도 축소
        previewView.imageAlignment = .alignCenter
        previewPanel.addSubview(previewView)

        // 작은 미리보기 (32px)
        previewSmallView = NSImageView()
        previewSmallView.translatesAutoresizingMaskIntoConstraints = false
        previewSmallView.imageScaling = .scaleProportionallyDown
        previewSmallView.imageAlignment = .alignCenter
        previewPanel.addSubview(previewSmallView)

        let smallLabel = NSTextField(labelWithString: "32px")
        smallLabel.translatesAutoresizingMaskIntoConstraints = false
        smallLabel.font = NSFont.systemFont(ofSize: 10)
        smallLabel.textColor = .secondaryLabelColor
        previewPanel.addSubview(smallLabel)

        // ── 우측: 컨트롤 패널
        let controlScroll = NSScrollView()
        controlScroll.translatesAutoresizingMaskIntoConstraints = false
        controlScroll.hasVerticalScroller = true
        controlScroll.autohidesScrollers = true
        // documentView가 상단부터 쌓이게: flipped=true 설정
        controlScroll.contentView.postsBoundsChangedNotifications = false
        contentView.addSubview(controlScroll)

        let controlPanel = NSView()
        controlPanel.translatesAutoresizingMaskIntoConstraints = false
        controlScroll.documentView = controlPanel

        // 컨트롤 패널을 scrollView contentView 상단에 고정 (controls at top, not bottom)
        NSLayoutConstraint.activate([
            controlPanel.topAnchor.constraint(equalTo: controlScroll.contentView.topAnchor),
            controlPanel.leadingAnchor.constraint(equalTo: controlScroll.contentView.leadingAnchor),
            controlPanel.trailingAnchor.constraint(equalTo: controlScroll.contentView.trailingAnchor),
        ])

        // ── 하단: 버튼 & 상태 라벨
        let buttonBar = NSView()
        buttonBar.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(buttonBar)

        let btnPNG = NSButton(title: "PNG 내보내기", target: self, action: #selector(exportPNG))
        btnPNG.translatesAutoresizingMaskIntoConstraints = false
        btnPNG.bezelStyle = .rounded

        let btnIcns = NSButton(title: ".icns 생성", target: self, action: #selector(exportIcns))
        btnIcns.translatesAutoresizingMaskIntoConstraints = false
        btnIcns.bezelStyle = .rounded

        let btnConst = NSButton(title: "상수 출력", target: self, action: #selector(printConstants))
        btnConst.translatesAutoresizingMaskIntoConstraints = false
        btnConst.bezelStyle = .rounded

        statusLabel = NSTextField(labelWithString: "준비")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.maximumNumberOfLines = 3

        buttonBar.addSubview(btnPNG)
        buttonBar.addSubview(btnIcns)
        buttonBar.addSubview(btnConst)
        buttonBar.addSubview(statusLabel)

        // ── Layout constraints (최상위)
        NSLayoutConstraint.activate([
            // 좌측 미리보기 패널
            previewPanel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            previewPanel.topAnchor.constraint(equalTo: contentView.topAnchor),
            previewPanel.bottomAnchor.constraint(equalTo: buttonBar.topAnchor),
            previewPanel.widthAnchor.constraint(equalToConstant: 360),

            // 우측 컨트롤 스크롤
            controlScroll.leadingAnchor.constraint(equalTo: previewPanel.trailingAnchor, constant: 8),
            controlScroll.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            controlScroll.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            controlScroll.bottomAnchor.constraint(equalTo: buttonBar.topAnchor, constant: -8),

            // 하단 버튼 바
            buttonBar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            buttonBar.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            buttonBar.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            buttonBar.heightAnchor.constraint(equalToConstant: 80),
        ])

        // 미리보기 패널 내부 layout
        // NSImageView 기본 intrinsicContentSize = 이미지 크기(1024pt) → 창을 강제로 키움
        // compression resistance를 낮춰 창 크기에 맞게 축소되게
        previewView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        previewView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        checker.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        NSLayoutConstraint.activate([
            // 체커보드+프리뷰: 패널 전체 (하단 썸네일 행 44pt 제외)
            checker.leadingAnchor.constraint(equalTo: previewPanel.leadingAnchor, constant: 8),
            checker.trailingAnchor.constraint(equalTo: previewPanel.trailingAnchor, constant: -8),
            checker.topAnchor.constraint(equalTo: previewPanel.topAnchor, constant: 8),
            checker.bottomAnchor.constraint(equalTo: previewPanel.bottomAnchor, constant: -48),

            // 프리뷰는 체커 영역 전체 채움
            previewView.leadingAnchor.constraint(equalTo: checker.leadingAnchor),
            previewView.trailingAnchor.constraint(equalTo: checker.trailingAnchor),
            previewView.topAnchor.constraint(equalTo: checker.topAnchor),
            previewView.bottomAnchor.constraint(equalTo: checker.bottomAnchor),

            // 32px 썸네일: 하단 고정
            previewSmallView.trailingAnchor.constraint(equalTo: previewPanel.trailingAnchor, constant: -12),
            previewSmallView.bottomAnchor.constraint(equalTo: previewPanel.bottomAnchor, constant: -8),
            previewSmallView.widthAnchor.constraint(equalToConstant: 32),
            previewSmallView.heightAnchor.constraint(equalToConstant: 32),

            smallLabel.trailingAnchor.constraint(equalTo: previewSmallView.leadingAnchor, constant: -4),
            smallLabel.centerYAnchor.constraint(equalTo: previewSmallView.centerYAnchor),
        ])

        // 버튼 바 내부 layout
        NSLayoutConstraint.activate([
            btnPNG.leadingAnchor.constraint(equalTo: buttonBar.leadingAnchor, constant: 12),
            btnPNG.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor),

            btnIcns.leadingAnchor.constraint(equalTo: btnPNG.trailingAnchor, constant: 8),
            btnIcns.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor),

            btnConst.leadingAnchor.constraint(equalTo: btnIcns.trailingAnchor, constant: 8),
            btnConst.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor),

            statusLabel.leadingAnchor.constraint(equalTo: btnConst.trailingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: buttonBar.trailingAnchor, constant: -12),
            statusLabel.centerYAnchor.constraint(equalTo: buttonBar.centerYAnchor),
        ])

        // ── 슬라이더 컨트롤 패널 구성
        buildControlPanel(controlPanel, in: controlScroll)
    }

    func buildControlPanel(_ panel: NSView, in scroll: NSScrollView) {
        var rows: [NSView] = []

        // 섹션 헤더 헬퍼
        func sectionHeader(_ text: String) -> NSTextField {
            let lbl = NSTextField(labelWithString: text)
            lbl.translatesAutoresizingMaskIntoConstraints = false
            lbl.font = NSFont.boldSystemFont(ofSize: 12)
            lbl.textColor = .labelColor
            return lbl
        }

        // ── 섹션: 글리프 크기
        rows.append(sectionHeader("── 글리프 크기"))

        let (row1, s1, v1) = makeSliderRow(
            label: "keyboardSizeRatio", minVal: 0.30, maxVal: 0.80,
            current: Double(params.keyboardSizeRatio),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.keyboardSizeRatio.rawValue
        )
        valueLabels[Tag.keyboardSizeRatio.rawValue] = v1
        rows.append(row1)

        let (row2, s2, v2) = makeSliderRow(
            label: "cmdSizeRatio", minVal: 0.20, maxVal: 0.70,
            current: Double(params.cmdSizeRatio),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.cmdSizeRatio.rawValue
        )
        valueLabels[Tag.cmdSizeRatio.rawValue] = v2
        rows.append(row2)

        let (row3, s3, v3) = makeSliderRow(
            label: "glyphGap (px)", minVal: 0, maxVal: 200,
            current: Double(params.glyphGap),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.glyphGap.rawValue
        )
        valueLabels[Tag.glyphGap.rawValue] = v3
        rows.append(row3)

        // ── 섹션: 라운드렉트
        rows.append(sectionHeader("── 라운드렉트"))

        let (row4, s4, v4) = makeSliderRow(
            label: "cornerRatio", minVal: 0.10, maxVal: 0.35,
            current: Double(params.cornerRatio),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.cornerRatio.rawValue
        )
        valueLabels[Tag.cornerRatio.rawValue] = v4
        rows.append(row4)

        let (row5, s5, v5) = makeSliderRow(
            label: "squirclePadding", minVal: 0, maxVal: 0.15,
            current: Double(params.squirclePaddingRatio),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.squirclePadding.rawValue
        )
        valueLabels[Tag.squirclePadding.rawValue] = v5
        rows.append(row5)

        // ── 섹션: 그림자
        rows.append(sectionHeader("── 그림자"))

        let (row6, s6, v6) = makeSliderRow(
            label: "shadowAlpha", minVal: 0, maxVal: 0.5,
            current: Double(params.shadowAlpha),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.shadowAlpha.rawValue
        )
        valueLabels[Tag.shadowAlpha.rawValue] = v6
        rows.append(row6)

        let (row7, s7, v7) = makeSliderRow(
            label: "shadowBlur", minVal: 0, maxVal: 30,
            current: Double(params.shadowBlur),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.shadowBlur.rawValue
        )
        valueLabels[Tag.shadowBlur.rawValue] = v7
        rows.append(row7)

        let (row8, s8, v8) = makeSliderRow(
            label: "shadowOffsetY", minVal: -20, maxVal: 0,
            current: Double(params.shadowOffsetY),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.shadowOffsetY.rawValue
        )
        valueLabels[Tag.shadowOffsetY.rawValue] = v8
        rows.append(row8)

        // ── 섹션: 그라데이션
        rows.append(sectionHeader("── 그라데이션"))

        let (row9, s9, v9) = makeSliderRow(
            label: "gradientAngle (°)", minVal: -90, maxVal: 0,
            current: Double(params.gradientAngle),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.gradientAngle.rawValue
        )
        valueLabels[Tag.gradientAngle.rawValue] = v9
        rows.append(row9)

        // NSColorWell 3개
        rows.append(sectionHeader("── 그라데이션 색상"))
        rows.append(makeColorRow(label: "violet", color: params.violetColor, tag: 100))
        rows.append(makeColorRow(label: "cyan",   color: params.cyanColor,   tag: 101))
        rows.append(makeColorRow(label: "dark",   color: params.darkColor,   tag: 102))

        // ── 섹션: 내부 패딩
        rows.append(sectionHeader("── 글리프 위치 (양수=오른쪽/아래, px)"))

        let (row10, s10, v10) = makeSliderRow(
            label: "keyboard X", minVal: -300, maxVal: 300,
            current: Double(params.kbOffsetX),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.kbOffsetX.rawValue
        )
        valueLabels[Tag.kbOffsetX.rawValue] = v10
        rows.append(row10)

        let (row11, s11, v11) = makeSliderRow(
            label: "keyboard Y", minVal: -300, maxVal: 300,
            current: Double(params.kbOffsetY),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.kbOffsetY.rawValue
        )
        valueLabels[Tag.kbOffsetY.rawValue] = v11
        rows.append(row11)

        let (row12, s12, v12) = makeSliderRow(
            label: "⌘ X", minVal: -300, maxVal: 300,
            current: Double(params.cmdOffsetX),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.cmdOffsetX.rawValue
        )
        valueLabels[Tag.cmdOffsetX.rawValue] = v12
        rows.append(row12)

        let (row13, s13, v13) = makeSliderRow(
            label: "⌘ Y", minVal: -300, maxVal: 300,
            current: Double(params.cmdOffsetY),
            target: self, action: #selector(sliderChanged(_:)), tag: Tag.cmdOffsetY.rawValue
        )
        valueLabels[Tag.cmdOffsetY.rawValue] = v13
        rows.append(row13)

        // ── 패널에 행 추가
        var prevAnchor = panel.topAnchor
        let topPad: CGFloat = 12
        for (i, row) in rows.enumerated() {
            panel.addSubview(row)
            let topConst = i == 0 ? topPad : 6.0
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: prevAnchor, constant: topConst),
                row.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 12),
                row.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -12),
            ])
            prevAnchor = row.bottomAnchor
        }

        // 마지막 행 하단 패딩
        if let lastRow = rows.last {
            let bottom = lastRow.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -12)
            bottom.isActive = true
        }

        // 너비는 setupUI의 contentView 제약으로 이미 결정됨 (중복 제거)

        // sliders 딕셔너리 등록 + 필드 target/action 연결 (양방향 동기)
        let allPairs: [(NSSlider, NSTextField)] = [
            (s1,v1),(s2,v2),(s3,v3),(s4,v4),(s5,v5),(s6,v6),
            (s7,v7),(s8,v8),(s9,v9),(s10,v10),(s11,v11),(s12,v12),(s13,v13),
        ]
        for (sl, fld) in allPairs {
            sliders[sl.tag] = sl
            fld.target = self
            fld.action = #selector(valueFieldCommitted(_:))
        }
    }

    func makeColorRow(label: String, color: NSColor, tag: Int) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let lbl = NSTextField(labelWithString: label)
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        lbl.alignment = .right

        let well = NSColorWell()
        well.translatesAutoresizingMaskIntoConstraints = false
        well.color = color
        well.tag = tag
        well.target = self
        well.action = #selector(colorChanged(_:))

        row.addSubview(lbl)
        row.addSubview(well)

        NSLayoutConstraint.activate([
            lbl.leadingAnchor.constraint(equalTo: row.leadingAnchor),
            lbl.widthAnchor.constraint(equalToConstant: 130),
            lbl.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            well.leadingAnchor.constraint(equalTo: lbl.trailingAnchor, constant: 8),
            well.widthAnchor.constraint(equalToConstant: 60),
            well.heightAnchor.constraint(equalToConstant: 28),
            well.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            row.heightAnchor.constraint(equalToConstant: 32),
        ])

        return row
    }

    // ── 슬라이더 액션
    @objc func sliderChanged(_ sender: NSSlider) {
        let val = CGFloat(sender.doubleValue)
        // 필드 표시값 갱신 (슬라이더와 동일 tag로 찾음)
        if let fld = valueLabels[sender.tag] {
            fld.stringValue = formattedValue(sender.doubleValue, tag: sender.tag)
        }
        applyValue(val, tag: sender.tag)
        rerender()
    }

    // ── 수치 필드 커밋 (Enter / 포커스 아웃)
    @objc func valueFieldCommitted(_ sender: NSTextField) {
        let tag = sender.tag
        guard let slider = sliders[tag] else { return }

        // 파싱 실패 → 슬라이더 현재값으로 되돌림
        guard let parsed = Double(sender.stringValue.trimmingCharacters(in: .whitespaces)) else {
            sender.stringValue = formattedValue(slider.doubleValue, tag: tag)
            return
        }

        // 슬라이더 범위로 클램프
        let clamped = max(slider.minValue, min(slider.maxValue, parsed))

        // 슬라이더 위치 갱신
        slider.doubleValue = clamped

        // 필드 표시값 정규화
        sender.stringValue = formattedValue(clamped, tag: tag)

        // 파라미터 반영 (sliderChanged와 동일 로직 공유)
        applyValue(CGFloat(clamped), tag: tag)
        rerender()
    }

    // ── 포맷 헬퍼 (tag에 따라 %.1f / %.4f)
    private func formattedValue(_ val: Double, tag: Int) -> String {
        let intLike = tag == Tag.glyphGap.rawValue     ||
                      tag == Tag.shadowBlur.rawValue    ||
                      tag == Tag.shadowOffsetY.rawValue ||
                      tag == Tag.gradientAngle.rawValue ||
                      tag == Tag.kbOffsetX.rawValue     ||
                      tag == Tag.kbOffsetY.rawValue     ||
                      tag == Tag.cmdOffsetX.rawValue    ||
                      tag == Tag.cmdOffsetY.rawValue
        return intLike ? String(format: "%.1f", val) : String(format: "%.4f", val)
    }

    // ── 파라미터 적용 (sliderChanged / valueFieldCommitted 공통)
    private func applyValue(_ val: CGFloat, tag: Int) {
        switch tag {
        case Tag.keyboardSizeRatio.rawValue: params.keyboardSizeRatio     = val
        case Tag.cmdSizeRatio.rawValue:      params.cmdSizeRatio           = val
        case Tag.glyphGap.rawValue:          params.glyphGap               = val
        case Tag.cornerRatio.rawValue:       params.cornerRatio            = val
        case Tag.shadowAlpha.rawValue:       params.shadowAlpha            = val
        case Tag.shadowBlur.rawValue:        params.shadowBlur             = val
        case Tag.shadowOffsetY.rawValue:     params.shadowOffsetY          = val
        case Tag.gradientAngle.rawValue:     params.gradientAngle          = val
        case Tag.squirclePadding.rawValue:   params.squirclePaddingRatio   = val
        case Tag.kbOffsetX.rawValue:         params.kbOffsetX              = val
        case Tag.kbOffsetY.rawValue:         params.kbOffsetY              = val
        case Tag.cmdOffsetX.rawValue:        params.cmdOffsetX             = val
        case Tag.cmdOffsetY.rawValue:        params.cmdOffsetY             = val
        default: break
        }
    }

    // ── 컬러웰 액션
    @objc func colorChanged(_ sender: NSColorWell) {
        switch sender.tag {
        case 100: params.violetColor = sender.color
        case 101: params.cyanColor   = sender.color
        case 102: params.darkColor   = sender.color
        default: break
        }
        rerender()
    }

    // ── 실시간 재렌더
    func rerender() {
        let img = renderIcon(params: params)
        previewView.image = img
        previewSmallView.image = img
    }

    // ── PNG 내보내기
    @objc func exportPNG() {
        let outURL = repoRoot.appendingPathComponent("Resources/icon-master.png")
        let img = renderIcon(params: params)
        guard let bitmap = img.representations.first as? NSBitmapImageRep,
              let data = bitmap.representation(using: .png, properties: [:]) else {
            statusLabel.stringValue = "PNG 인코딩 실패"
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: outURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: outURL)
            statusLabel.stringValue = "PNG 저장: \(outURL.path)"
            print("PNG 저장: \(outURL.path)")
        } catch {
            statusLabel.stringValue = "PNG 쓰기 실패: \(error)"
        }
    }

    // ── .icns 생성
    @objc func exportIcns() {
        // 먼저 PNG 저장
        let pngURL  = repoRoot.appendingPathComponent("Resources/icon-master.png")
        let icnsURL = repoRoot.appendingPathComponent("Resources/AppIcon.icns")

        let img = renderIcon(params: params)
        guard let bitmap = img.representations.first as? NSBitmapImageRep,
              let data = bitmap.representation(using: .png, properties: [:]) else {
            statusLabel.stringValue = "PNG 인코딩 실패"
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: pngURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: pngURL)
        } catch {
            statusLabel.stringValue = "PNG 쓰기 실패: \(error)"
            return
        }

        // icns 생성
        do {
            try buildIcnsFile(from: pngURL.path, outputPath: icnsURL.path)
            statusLabel.stringValue = ".icns 생성 완료: \(icnsURL.path)"
            print(".icns 생성 완료: \(icnsURL.path)")
        } catch {
            statusLabel.stringValue = ".icns 생성 실패: \(error)"
        }
    }

    // ── 상수 출력
    @objc func printConstants() {
        let p = params
        let out = """
// make-icon.swift 붙여넣기용 상수 ──────────────────────────
let CANVAS: CGFloat           = \(Int(p.canvas))
let SQUIRCLE_PADDING_RATIO: CGFloat = \(String(format: "%.6f", p.squirclePaddingRatio))  // padding/canvas
let CORNER_RATIO: CGFloat     = \(String(format: "%.4f", p.cornerRatio))
let KEYBOARD_SIZE_RATIO: CGFloat = \(String(format: "%.4f", p.keyboardSizeRatio))
let CMD_SIZE_RATIO: CGFloat   = \(String(format: "%.4f", p.cmdSizeRatio))
let GLYPH_GAP: CGFloat        = \(String(format: "%.1f", p.glyphGap))
let SHADOW_ALPHA: CGFloat     = \(String(format: "%.4f", p.shadowAlpha))
let SHADOW_BLUR: CGFloat      = \(String(format: "%.1f", p.shadowBlur))
let SHADOW_OFFSET_Y: CGFloat  = \(String(format: "%.1f", p.shadowOffsetY))
let GRADIENT_ANGLE: CGFloat   = \(String(format: "%.1f", p.gradientAngle))   // degrees
let COLOR_VIOLET = CGColor(srgbRed: \(String(format: "%.3f", p.violetColor.redComponent)), green: \(String(format: "%.3f", p.violetColor.greenComponent)), blue: \(String(format: "%.3f", p.violetColor.blueComponent)), alpha: 1.0)
let COLOR_CYAN   = CGColor(srgbRed: \(String(format: "%.3f", p.cyanColor.redComponent)), green: \(String(format: "%.3f", p.cyanColor.greenComponent)), blue: \(String(format: "%.3f", p.cyanColor.blueComponent)), alpha: 1.0)
let COLOR_DARK   = CGColor(srgbRed: \(String(format: "%.3f", p.darkColor.redComponent)), green: \(String(format: "%.3f", p.darkColor.greenComponent)), blue: \(String(format: "%.3f", p.darkColor.blueComponent)), alpha: 1.0)
let KB_OFFSET_X:  CGFloat = \(String(format: "%.1f", p.kbOffsetX))   // keyboard 가로 nudge (양수=오른쪽)
let KB_OFFSET_Y:  CGFloat = \(String(format: "%.1f", p.kbOffsetY))   // keyboard 세로 nudge (양수=아래)
let CMD_OFFSET_X: CGFloat = \(String(format: "%.1f", p.cmdOffsetX))   // command  가로 nudge (양수=오른쪽)
let CMD_OFFSET_Y: CGFloat = \(String(format: "%.1f", p.cmdOffsetY))   // command  세로 nudge (양수=아래)
// ────────────────────────────────────────────────────────────
"""
        print(out)
        statusLabel.stringValue = "상수 콘솔 출력 완료 (터미널 확인)"
    }
}

// ─────────────────────────────────────────
// MARK: - CheckerboardView (투명도 확인용 배경)
// ─────────────────────────────────────────

class CheckerboardView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let tileSize: CGFloat = 16
        let light = NSColor(white: 0.9, alpha: 1)
        let dark  = NSColor(white: 0.7, alpha: 1)
        let cols = Int(ceil(bounds.width  / tileSize))
        let rows = Int(ceil(bounds.height / tileSize))
        for row in 0..<rows {
            for col in 0..<cols {
                let isLight = (row + col) % 2 == 0
                (isLight ? light : dark).setFill()
                let rect = CGRect(x: CGFloat(col) * tileSize,
                                  y: CGFloat(row) * tileSize,
                                  width: tileSize, height: tileSize)
                NSBezierPath(rect: rect.intersection(bounds)).fill()
            }
        }
    }
}

// ─────────────────────────────────────────
// MARK: - AppDelegate & 진입점
// ─────────────────────────────────────────

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let vc = TunerViewController()

        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered, defer: false
        )
        window.title = "Icon Tuner — cmd-hanyoung"
        window.contentViewController = vc
        // contentViewController 설정 후 명시적으로 크기 강제 — autolayout이 창을 키우는 것 차단
        window.setContentSize(NSSize(width: 800, height: 600))
        // 최소 창 크기
        window.minSize = NSSize(width: 720, height: 420)
        window.center()
        window.makeKeyAndOrderFront(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// ── NSApplication 수동 구동 (single-file script 호환)
let app      = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.activate(ignoringOtherApps: true)
app.run()
