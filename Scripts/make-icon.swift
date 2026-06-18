#!/usr/bin/env swift
// make-icon.swift
// 1024×1024 macOS 앱 아이콘 PNG 생성 스크립트
// 실행: swift Scripts/make-icon.swift
// 출력: Resources/icon-master.png

import AppKit
import CoreGraphics

// ─────────────────────────────────────────
// MARK: - 캔버스 & 라운드렉트 상수
// macOS 앱 아이콘 그리드: 1024 캔버스, 824 아이콘, 100 gutter, r=185.4 (Apple HIG)
// ─────────────────────────────────────────

let CANVAS: CGFloat        = 1024   // 캔버스 한 변 (px)
let SQUIRCLE_SIZE: CGFloat = 824    // 라운드렉트 한 변 (각 변 100px 패딩)
let PADDING: CGFloat       = (CANVAS - SQUIRCLE_SIZE) / 2  // 100px

// 모서리 반지름 ≈ 0.225 × 824 ≈ 185.4px
let CORNER_RADIUS: CGFloat = SQUIRCLE_SIZE * 0.225

// 배경 그라데이션 색상 & 각도
// GRADIENT_ANGLE: 0°=좌→우, -90°=위→아래, -45°=좌상→우하 (CG y-up 기준)
// 튜너 확정값: -65.9°
let GRADIENT_ANGLE: CGFloat = -65.9
let COLOR_VIOLET = CGColor(srgbRed: 0.616, green: 0.361, blue: 0.965, alpha: 1.0)  // #9D5CF6
let COLOR_CYAN   = CGColor(srgbRed: 0.024, green: 0.714, blue: 0.831, alpha: 1.0)  // #06B6D4
let COLOR_DARK   = CGColor(srgbRed: 0.01,  green: 0.44,  blue: 0.54,  alpha: 1.0)  // 하단 볼륨감

// ─────────────────────────────────────────
// MARK: - SF Symbol ink 측정값 (semibold, 실측 frac)
// ─────────────────────────────────────────
// *Frac = draw-rect 안에서 해당 방향 투명 여백 비율
// ink*  = 실제 글리프가 차지하는 비율 / aspect

// keyboard
let KB_LEFT_FRAC:        CGFloat = 0.0823
let KB_RIGHT_FRAC:       CGFloat = 0.0831
let KB_TOP_FRAC:         CGFloat = 0.0894
let KB_BOTTOM_FRAC:      CGFloat = 0.0894
let KB_INK_WIDTH_FRAC:   CGFloat = 0.8346
let KB_INK_HEIGHT_FRAC:  CGFloat = 0.8212
let KB_ASPECT:           CGFloat = 1.5364  // draw-rect width / height

// command (⌘)
let CMD_LEFT_FRAC:       CGFloat = 0.1044
let CMD_RIGHT_FRAC:      CGFloat = 0.1044
let CMD_TOP_FRAC:        CGFloat = 0.0787
let CMD_BOTTOM_FRAC:     CGFloat = 0.0787
let CMD_INK_WIDTH_FRAC:  CGFloat = 0.7911
let CMD_INK_HEIGHT_FRAC: CGFloat = 0.8425
let CMD_ASPECT:          CGFloat = 1.0664

// ─────────────────────────────────────────
// MARK: - 글리프 draw-rect 크기
// ─────────────────────────────────────────

let KEYBOARD_SIZE_RATIO: CGFloat = 0.6634   // keyboard draw-rect 폭 / squircle (튜너 확정값)
let CMD_SIZE_RATIO:      CGFloat = 0.4264   // command draw-rect 폭 / squircle

let KB_DRAW_W:  CGFloat = KEYBOARD_SIZE_RATIO * SQUIRCLE_SIZE   // ≈ 516.2 px
let KB_DRAW_H:  CGFloat = KB_DRAW_W / KB_ASPECT                  // ≈ 335.9 px

let CMD_DRAW_W: CGFloat = CMD_SIZE_RATIO * SQUIRCLE_SIZE         // ≈ 395.7 px
let CMD_DRAW_H: CGFloat = CMD_DRAW_W / CMD_ASPECT                 // ≈ 371.1 px

// ─────────────────────────────────────────
// MARK: - ink bbox 크기
// ─────────────────────────────────────────

let KB_INK_W:  CGFloat = KB_INK_WIDTH_FRAC  * KB_DRAW_W    // ≈ 430.8 px
let KB_INK_H:  CGFloat = KB_INK_HEIGHT_FRAC * KB_DRAW_H    // ≈ 275.9 px

let CMD_INK_W: CGFloat = CMD_INK_WIDTH_FRAC  * CMD_DRAW_W  // ≈ 313.0 px
let CMD_INK_H: CGFloat = CMD_INK_HEIGHT_FRAC * CMD_DRAW_H  // ≈ 312.6 px

// ─────────────────────────────────────────
// MARK: - union bbox 중앙정렬 레이아웃
// ─────────────────────────────────────────
//
// 알고리즘 (로컬 좌표 = x 우방향, y 아래방향):
//   1) keyboard ink origin을 로컬 (0, 0) 으로 기준점 설정
//   2) command ink를 keyboard ink 우하단에서 GLYPH_GAP 만큼 이격
//      cmd_ink_local = (KB_INK_W + GLYPH_GAP, KB_INK_H + GLYPH_GAP)
//   3) union bbox: (0,0) ~ (cmd_ink_local.x + CMD_INK_W, cmd_ink_local.y + CMD_INK_H)
//   4) union 중심 = (unionW/2, unionH/2)
//   5) squircle 중심 (CG 절대 = y-up): (PADDING + SQUIRCLE_SIZE/2, PADDING + SQUIRCLE_SIZE/2)
//   6) translate = squircle중심 - union중심 (로컬 y→CG y 부호 변환 필요)
//      CG y-up에서 "로컬 y 아래 = CG y 감소", 기준점(kb ink top-left)의 CG y = 절대 y
//      kb_ink_top_CG = squircle_cy + unionH/2 - 0  (로컬 origin이 union top-left)
//      → 실제로는: kb_ink_abs_x  = squircle_cx - unionW/2
//                   kb_ink_abs_top_CG = squircle_cy + unionH/2  (CG: y-up, top = 큰 y)
//
// GLYPH_GAP: keyboard ink 우하단 ↔ command ink 좌상단 대각 거리 (수평/수직 동일)
let GLYPH_GAP: CGFloat = 14.5   // px, keyboard→command 간격 (튜너 확정값)

// ─────────────────────────────────────────
// MARK: - 글리프별 독립 위치 오프셋 (squircle-local px, 기본 0)
// ─────────────────────────────────────────
// union bbox 중앙정렬 baseline 위에서 각 글리프를 독립적으로 nudge.
// 양수 Y = 화면상 아래 (AppKit y-up이므로 draw 좌표엔 -OFFSET_Y 적용).
// 기본 0,0,0,0 → 기존 정중앙 렌더와 완전 동일.
let KB_OFFSET_X:  CGFloat =  39.9   // keyboard 가로 nudge (양수=오른쪽)
let KB_OFFSET_Y:  CGFloat = -11.4   // keyboard 세로 nudge (양수=아래)
let CMD_OFFSET_X: CGFloat = -35.2   // command  가로 nudge (양수=오른쪽)
let CMD_OFFSET_Y: CGFloat =  32.4   // command  세로 nudge (양수=아래)

// union bbox 크기 (로컬)
let UNION_W: CGFloat = KB_INK_W + GLYPH_GAP + CMD_INK_W   // ≈ 724.5 px
let UNION_H: CGFloat = KB_INK_H + GLYPH_GAP + CMD_INK_H   // ≈ 586.5 px

// squircle 중심 (CG 절대 좌표, y-up)
let SQ_CX: CGFloat = PADDING + SQUIRCLE_SIZE / 2.0   // 512.0
let SQ_CY: CGFloat = PADDING + SQUIRCLE_SIZE / 2.0   // 512.0

// keyboard ink top-left (CG 절대) — union bbox 정중앙 배치
//   x = squircle_cx - unionW/2
//   y (CG y-up, top = 큰 값) = squircle_cy + unionH/2
let KB_INK_ABS_X:   CGFloat = SQ_CX - UNION_W / 2.0            // x 절대
let KB_INK_ABS_TOP: CGFloat = SQ_CY + UNION_H / 2.0            // CG top (y-up)

// keyboard draw-rect origin (CG 절대): ink 가장자리에서 frac 역산
//   drawX   = inkLeft - leftFrac × drawW
//   drawTop = inkTop  + topFrac  × drawH      (CG: top = drawTop, origin y = drawTop - drawH)
let KB_DRAW_X:   CGFloat = KB_INK_ABS_X   - KB_LEFT_FRAC   * KB_DRAW_W
let KB_DRAW_TOP: CGFloat = KB_INK_ABS_TOP + KB_TOP_FRAC    * KB_DRAW_H
let KB_DRAW_Y:   CGFloat = KB_DRAW_TOP    - KB_DRAW_H      // rect origin (하단 = 작은 y)

// command ink top-left (CG 절대):
//   로컬: (KB_INK_W + GLYPH_GAP, KB_INK_H + GLYPH_GAP) — y 아래방향
//   CG x = KB_INK_ABS_X + KB_INK_W + GLYPH_GAP
//   CG top(y-up) = KB_INK_ABS_TOP - KB_INK_H - GLYPH_GAP  (로컬 y↓ → CG y↑ 부호 반전)
let CMD_INK_ABS_X:   CGFloat = KB_INK_ABS_X   + KB_INK_W + GLYPH_GAP
let CMD_INK_ABS_TOP: CGFloat = KB_INK_ABS_TOP - KB_INK_H - GLYPH_GAP

// command draw-rect origin (CG 절대)
let CMD_DRAW_X:   CGFloat = CMD_INK_ABS_X   - CMD_LEFT_FRAC   * CMD_DRAW_W
let CMD_DRAW_TOP: CGFloat = CMD_INK_ABS_TOP + CMD_TOP_FRAC    * CMD_DRAW_H
let CMD_DRAW_Y:   CGFloat = CMD_DRAW_TOP    - CMD_DRAW_H

// ─────────────────────────────────────────
// MARK: - 그림자 상수
// ─────────────────────────────────────────

let SHADOW_ALPHA:    CGFloat = 0.25
let SHADOW_BLUR:     CGFloat = 6.0
let SHADOW_OFFSET_Y: CGFloat = -3.0  // NSGraphicsContext 좌표: 음수 = 아래

// ─────────────────────────────────────────
// MARK: - 헬퍼 함수
// ─────────────────────────────────────────

func makeRoundedRectPath(rect: CGRect, radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func makeShadow() -> NSShadow {
    let s = NSShadow()
    s.shadowOffset     = NSSize(width: 0, height: SHADOW_OFFSET_Y)
    s.shadowBlurRadius = SHADOW_BLUR
    s.shadowColor      = NSColor(white: 0, alpha: SHADOW_ALPHA)
    return s
}

// ─────────────────────────────────────────
// MARK: - 레이아웃 수치 출력 (디버그)
// ─────────────────────────────────────────

func printLayout() {
    print("=== 레이아웃 계산값 ===")
    print(String(format: "SQUIRCLE   : %.1f²  center=(%.1f, %.1f)", SQUIRCLE_SIZE, SQ_CX, SQ_CY))
    print(String(format: "KB  draw   : %.2f × %.2f", KB_DRAW_W, KB_DRAW_H))
    print(String(format: "KB  ink    : %.2f × %.2f", KB_INK_W, KB_INK_H))
    print(String(format: "CMD draw   : %.2f × %.2f", CMD_DRAW_W, CMD_DRAW_H))
    print(String(format: "CMD ink    : %.2f × %.2f", CMD_INK_W, CMD_INK_H))
    print(String(format: "GLYPH_GAP  : %.1f", GLYPH_GAP))
    print(String(format: "union bbox : %.2f × %.2f", UNION_W, UNION_H))
    // union 중심 검증 (절대 좌표)
    let unionCX = KB_INK_ABS_X   + UNION_W / 2.0
    let unionCY = KB_INK_ABS_TOP - UNION_H / 2.0   // CG y-up: top이 크므로 빼기
    print(String(format: "KB_OFFSET  : x=%.1f  y=%.1f  (양수=오른쪽/아래)", KB_OFFSET_X, KB_OFFSET_Y))
    print(String(format: "CMD_OFFSET : x=%.1f  y=%.1f  (양수=오른쪽/아래)", CMD_OFFSET_X, CMD_OFFSET_Y))
    print(String(format: "union center(CG) : (%.2f, %.2f)  ← 목표 (%.1f, %.1f)", unionCX, unionCY, SQ_CX, SQ_CY))
    print("--- keyboard ink bbox (CG 절대) ---")
    print(String(format: "  left=%.2f  top=%.2f  right=%.2f  bottom=%.2f",
          KB_INK_ABS_X, KB_INK_ABS_TOP,
          KB_INK_ABS_X + KB_INK_W, KB_INK_ABS_TOP - KB_INK_H))
    print("--- command ink bbox (CG 절대) ---")
    print(String(format: "  left=%.2f  top=%.2f  right=%.2f  bottom=%.2f",
          CMD_INK_ABS_X, CMD_INK_ABS_TOP,
          CMD_INK_ABS_X + CMD_INK_W, CMD_INK_ABS_TOP - CMD_INK_H))
    // squircle 기준 4면 외곽 여백 (ink 기준)
    let sq_minX = PADDING, sq_maxX = PADDING + SQUIRCLE_SIZE
    let sq_minY = PADDING, sq_maxY = PADDING + SQUIRCLE_SIZE
    let leftMargin   = KB_INK_ABS_X - sq_minX
    let topMargin    = sq_maxY - KB_INK_ABS_TOP          // CG: squircle.maxY - inkTop = 얼마나 아래있는지
    let rightMargin  = sq_maxX - (CMD_INK_ABS_X + CMD_INK_W)
    let bottomMargin = (CMD_INK_ABS_TOP - CMD_INK_H) - sq_minY
    print("--- squircle 기준 4면 외곽 여백 (ink) ---")
    print(String(format: "  left=%.1f  top=%.1f  right=%.1f  bottom=%.1f",
          leftMargin, topMargin, rightMargin, bottomMargin))
    let _ = sq_minX; let _ = sq_minY
}

// ─────────────────────────────────────────
// MARK: - 아이콘 렌더링
// ─────────────────────────────────────────

func renderIcon() -> NSImage {
    let size = NSSize(width: CANVAS, height: CANVAS)

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(CANVAS),
        pixelsHigh: Int(CANVAS),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .calibratedRGB,
        bytesPerRow: 0,
        bitsPerPixel: 32
    ) else { fatalError("NSBitmapImageRep 생성 실패") }

    guard let srgbSpace = CGColorSpace(name: CGColorSpace.sRGB),
          let ctx = CGContext(
              data: bitmap.bitmapData,
              width: Int(CANVAS),
              height: Int(CANVAS),
              bitsPerComponent: 8,
              bytesPerRow: bitmap.bytesPerRow,
              space: srgbSpace,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
          ) else { fatalError("CGContext 생성 실패") }

    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high

    // ── 0. 투명 배경
    ctx.clear(CGRect(x: 0, y: 0, width: CANVAS, height: CANVAS))

    // ── 1. squircle(라운드렉트) path — 4면 모두 PADDING(100px) 대칭
    let squircleRect = CGRect(
        x: PADDING, y: PADDING,
        width: SQUIRCLE_SIZE, height: SQUIRCLE_SIZE
    )
    let squirclePath = makeRoundedRectPath(rect: squircleRect, radius: CORNER_RADIUS)

    guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
        fatalError("sRGB 색공간 생성 실패")
    }

    // ── 2. 배경 그라데이션: violet→cyan, GRADIENT_ANGLE 기반 방향
    //    tuner와 동일 공식: squircle 중심에서 각도 방향으로 반지름 r 연장
    //    GRADIENT_ANGLE: 0°=좌→우, -90°=위→아래 (CG y-up 기준)
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()

    let gradColors = [COLOR_VIOLET, COLOR_CYAN, COLOR_DARK] as CFArray
    let gradLocs: [CGFloat] = [0.0, 0.72, 1.0]
    guard let gradient = CGGradient(colorsSpace: colorSpace, colors: gradColors, locations: gradLocs) else {
        fatalError("그라데이션 생성 실패")
    }

    // tuner의 renderIcon과 동일 공식 (squircle 중심 기준, 대각선 커버 반지름)
    let gradCX  = PADDING + SQUIRCLE_SIZE / 2.0
    let gradCY  = PADDING + SQUIRCLE_SIZE / 2.0
    let gradR   = SQUIRCLE_SIZE / 2.0 * 1.42
    let gradRad = GRADIENT_ANGLE * CGFloat.pi / 180.0
    let gradStart = CGPoint(x: gradCX - gradR * cos(gradRad), y: gradCY - gradR * sin(gradRad))
    let gradEnd   = CGPoint(x: gradCX + gradR * cos(gradRad), y: gradCY + gradR * sin(gradRad))
    ctx.drawLinearGradient(gradient, start: gradStart, end: gradEnd,
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    ctx.restoreGState()

    // ── 3. NSGraphicsContext 래핑 (flipped: false = y-up)
    let nsCtx = NSGraphicsContext(cgContext: ctx, flipped: false)

    // ── 4. keyboard 글리프 (좌상단)
    //    draw-rect 좌표: union bbox 중앙정렬 후 ink frac 역산
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

        // native size를 KB_DRAW_W 기준으로 스케일 (aspect 비율 보존)
        let nat   = kbFinal.size
        let scale = KB_DRAW_W / nat.width
        let drawW = nat.width  * scale   // = KB_DRAW_W
        let drawH = nat.height * scale   // ≈ KB_DRAW_H

        makeShadow().set()
        // KB_OFFSET_X/Y: 양수=오른쪽/아래. y-up이므로 Y는 부호 반전(-).
        kbFinal.draw(
            in: NSRect(x: KB_DRAW_X + KB_OFFSET_X, y: KB_DRAW_Y - KB_OFFSET_Y, width: drawW, height: drawH),
            from: .zero, operation: .sourceOver, fraction: 1.0
        )
        NSShadow().set()
    }

    NSGraphicsContext.restoreGraphicsState()

    // ── 5. command(⌘) 글리프 (우하단)
    //    keyboard와 동일한 weight .semibold, 동일 drop shadow
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
        let drawW = nat.width  * scale   // = CMD_DRAW_W
        let drawH = nat.height * scale   // ≈ CMD_DRAW_H

        makeShadow().set()
        // CMD_OFFSET_X/Y: 양수=오른쪽/아래. y-up이므로 Y는 부호 반전(-).
        cmdFinal.draw(
            in: NSRect(x: CMD_DRAW_X + CMD_OFFSET_X, y: CMD_DRAW_Y - CMD_OFFSET_Y, width: drawW, height: drawH),
            from: .zero, operation: .sourceOver, fraction: 1.0
        )
        NSShadow().set()
    }

    NSGraphicsContext.restoreGraphicsState()

    // ── 6. CGContext → NSBitmapImageRep
    guard let cgImage = ctx.makeImage() else {
        fatalError("CGImage 변환 실패")
    }

    let finalBitmap = NSBitmapImageRep(cgImage: cgImage)
    let image = NSImage(size: size)
    image.addRepresentation(finalBitmap)
    return image
}

// ─────────────────────────────────────────
// MARK: - 출력 경로 결정 & 실행
// ─────────────────────────────────────────

let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let repoRoot  = scriptURL.deletingLastPathComponent()
let outputURL = repoRoot.appendingPathComponent("Resources/icon-master.png")

printLayout()
print("아이콘 렌더링 시작...")
let image = renderIcon()

let bitmap = image.representations.first as! NSBitmapImageRep
guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("PNG 인코딩 실패")
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try pngData.write(to: outputURL)
    print("완료: \(outputURL.path)")
    print("크기: \(image.size.width)×\(image.size.height) pt")
} catch {
    fatalError("파일 쓰기 실패: \(error)")
}
