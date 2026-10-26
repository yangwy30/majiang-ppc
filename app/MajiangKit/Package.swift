// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MajiangKit",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "MajiangKit", targets: ["MajiangKit"]),
    ],
    targets: [
        // Vendored Guobiao fan calculator (ChineseOfficialMahjongHelper, MIT) behind a small C shim.
        .target(
            name: "CGuobiao",
            exclude: ["vendor/LICENSE"],
        ),
        .target(
            name: "MajiangKit",
            dependencies: ["CGuobiao"]
        ),
        .testTarget(
            name: "MajiangKitTests",
            dependencies: ["MajiangKit"],
            resources: [.copy("Fixtures")]
        ),
    ],
    cxxLanguageStandard: .cxx14
)
