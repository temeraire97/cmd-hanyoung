cask "cmd-hanyoung" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256"  # output of Scripts/release.sh; bump with version

  url "https://github.com/temeraire97/cmd-hanyoung/releases/download/v#{version}/cmd-hanyoung-#{version}.zip"
  name "cmd-hanyoung"
  desc "Tap left Command for English, right Command for Korean input switching"
  homepage "https://github.com/temeraire97/cmd-hanyoung"

  livecheck do
    url :url
    strategy :github_latest
  end

  app "cmd-hanyoung.app"

  zap trash: [
    "~/Library/Preferences/com.cmdhanyoung.app.plist",
  ]

  caveats <<~EOS
    cmd-hanyoung needs Accessibility permission:
      System Settings ▸ Privacy & Security ▸ Accessibility → enable cmd-hanyoung.

    This app is not notarized. If macOS blocks first launch, clear quarantine:
      xattr -dr com.apple.quarantine "#{appdir}/cmd-hanyoung.app"
    or use System Settings ▸ Privacy & Security ▸ "Open Anyway".
  EOS
end
