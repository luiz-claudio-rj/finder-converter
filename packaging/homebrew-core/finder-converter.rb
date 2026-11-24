class FinderConverter < Formula
  desc "Convert video, audio and images from the Finder's right-click menu"
  homepage "https://luiz-claudio-rj.github.io/finder-converter/"
  url "https://github.com/luiz-claudio-rj/finder-converter/archive/refs/tags/v1.2.1.tar.gz"
  sha256 "SHA256_DA_VERSAO"
  license "MIT"

  livecheck do
    url :stable
    strategy :github_latest
  end

  depends_on "ffmpeg"
  depends_on :macos
  depends_on "webp"

  def install
    libexec.install "converter.sh", "install.sh", "uninstall.sh", "VERSION", "workflow"
    bin.install "bin/finder-converter"
  end

  def caveats
    <<~EOS
      To add "Converter…" to the Finder's Quick Actions menu, run once:
        finder-converter setup
    EOS
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/finder-converter --version")

    system formula_opt_bin("ffmpeg")/"ffmpeg", "-loglevel", "error", "-f", "lavfi",
           "-i", "sine=frequency=440:duration=1", testpath/"tone.wav"
    with_env(SEM_JANELA: "1", SEM_AVISO: "1", FORMATO: "MP3") do
      system "zsh", libexec/"converter.sh", testpath/"tone.wav"
    end
    assert_path_exists testpath/"tone.mp3"
    assert_match "mp3", shell_output("#{formula_opt_bin("ffmpeg")}/ffprobe -v error " \
                                     "-show_entries format=format_name -of csv=p=0 #{testpath}/tone.mp3")
  end
end
