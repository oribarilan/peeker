# The Homebrew cask for oribarilan/homebrew-tap. The release workflow fills in the version and checksum
# (scripts/fill-cask.sh) and commits the result there as Casks/peeker.rb.
cask "peeker" do
  version "@VERSION@"
  sha256 "@SHA256@"

  url "https://github.com/oribarilan/peeker/releases/download/v#{version}/Peeker-#{version}.dmg"
  name "Peeker"
  desc "Viewer and editor for text, Markdown, PDFs and images"
  homepage "https://github.com/oribarilan/peeker"

  livecheck do
    url "https://oribarilan.github.io/peeker/appcast.xml"
    strategy :sparkle
  end

  auto_updates true
  depends_on macos: :tahoe

  app "Peeker.app"

  zap trash: [
    "~/Library/Application Support/dev.peeker.Peeker",
    "~/Library/Caches/dev.peeker.Peeker",
    "~/Library/HTTPStorages/dev.peeker.Peeker",
    "~/Library/Preferences/dev.peeker.Peeker.plist",
  ]
end
