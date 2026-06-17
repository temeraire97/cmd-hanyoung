// swift-tools-version:5.9
// cmd-hanyoung 패키지 정의

import PackageDescription

let package = Package(
    name: "cmd-hanyoung",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // 순수 로직 라이브러리 — CGEventTap 의존 없음, 테스트 가능
        .target(
            name: "SoloTapDetectorCore",
            path: "Sources/SoloTapDetectorCore"
        ),
        // 메인 실행 타겟
        .executableTarget(
            name: "cmd-hanyoung",
            dependencies: ["SoloTapDetectorCore"],
            path: "Sources/cmd-hanyoung",
            linkerSettings: [
                // Cocoa UI 프레임워크
                .linkedFramework("Cocoa"),
                // Carbon — TIS(텍스트 입력 소스) API 사용 대비
                .linkedFramework("Carbon"),
                // ServiceManagement — SMAppService(로그인 항목) 사용 대비
                .linkedFramework("ServiceManagement"),
                // ApplicationServices — AX(접근성) API 사용 대비
                .linkedFramework("ApplicationServices"),
            ]
        ),
        // 테스트 타겟 — Swift Testing 사용
        .testTarget(
            name: "cmd-hanyoungTests",
            dependencies: ["SoloTapDetectorCore"],
            path: "Tests/cmd-hanyoungTests",
            swiftSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-framework", "Testing",
                    "-framework", "_Testing_Foundation",
                    "-Xlinker", "-rpath",
                    "-Xlinker", "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ]
        ),
    ]
)
