cask "finder-converter" do
  version "1.4.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/luiz-claudio-rj/finder-converter/archive/refs/tags/v#{version}.tar.gz"
  name "Converter"
  desc "Convert video, audio and images from the Finder's right-click menu"
  homepage "https://luiz-claudio-rj.github.io/finder-converter/"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on formula: ["ffmpeg", "webp"]
  depends_on macos: :ventura

  app "finder-converter-#{version}/Converter.app"
  binary "finder-converter-#{version}/bin/finder-converter"
  service "finder-converter-#{version}/workflow/Converter.workflow"

  # Puts the script inside the Quick Action before it moves to ~/Library/Services
  preflight_steps do
    mkdir_p "finder-converter-#{version}/workflow/Converter.workflow/Contents/Resources", base: :staged_path
    copy "finder-converter-#{version}/converter.sh",
         "finder-converter-#{version}/workflow/Converter.workflow/Contents/Resources/converter.sh",
         source_base: :staged_path, target_base: :staged_path
    set_permissions "finder-converter-#{version}/workflow/Converter.workflow/Contents/Resources/converter.sh",
                    "0755", base: :staged_path
    # Builds the app locally with osacompile, which ships with macOS
    run "/bin/zsh", args: ["app/montar.sh", "Converter.app"], chdir: "finder-converter-{{version}}"
  end

  # Enables "Converter…" in the Finder context menu and Quick Actions
  postflight_steps do
    run "/usr/bin/defaults",
        args:           ["write", "pbs", "NSServicesStatus", "-dict-add",
                         "\"(null) - Converter… - runWorkflowAsService\"",
                         "<dict><key>presentation_modes</key><dict>" \
                         "<key>ContextMenu</key><true/><key>FinderPreview</key><true/>" \
                         "<key>ServicesMenu</key><true/><key>TouchBar</key><false/>" \
                         "</dict></dict>"],
        writable_paths: ["Library/Preferences"],
        writable_base:  :home
    run "/System/Library/CoreServices/pbs", args: ["-update"], must_succeed: false
    # Finder only reads the Quick Actions list at launch; it relaunches by itself
    terminate_process "Finder"
  end

  # removes "Converter…" from the menu right away
  uninstall_postflight_steps do
    terminate_process "Finder"
  end

  uninstall quit: "io.github.luiz-claudio-rj.converter"

  zap trash: [
    "~/Library/Application Support/Converter",
    "~/Library/Logs/Converter.log",
  ]

  caveats <<~EOS
    In Finder: right-click a video, audio or image file → Quick Actions → Converter…
    Or open the Converter app and drop files on its window.
  EOS
end
