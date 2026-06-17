// swift-tools-version:5.9
// cmd-hanyoung 패키지 정의

import PackageDescription

let package = Package(
    name: "cmd-hanyoung",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        // 메인 실행 타겟
        .executableTarget(
            name: "cmd-hanyoung",
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
        // 테스트 타겟 (이후 슬라이스에서 실제 테스트 추가)
        .testTarget(
            name: "cmd-hanyoungTests",
            dependencies: [],
            path: "Tests/cmd-hanyoungTests"
        ),
    ]
)
