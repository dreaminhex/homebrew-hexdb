# Homebrew formula for the tap github.com/dreaminhex/homebrew-hexdb:
#   brew install dreaminhex/hexdb/hexdb
#
# The release workflow's homebrew job copies this file into the tap with the
# version and the four sha256 values filled in from the release's SHA256SUMS,
# so the copy here only needs editing when the formula itself changes.
class Hexdb < Formula
  desc "Document database with REST, GraphQL, SQL, replication and an admin UI"
  homepage "https://hexdb.app"
  version "2.5.6"
  license "Apache-2.0"

  on_macos do
    on_arm do
      url "https://github.com/dreaminhex/hexdb/releases/download/v#{version}/hexdb-v#{version}-aarch64-apple-darwin.tar.gz"
      sha256 "9265afd8a8da5c8f57486af6be6193023cd13fbf690306f748005e869fd69025"
    end
    on_intel do
      url "https://github.com/dreaminhex/hexdb/releases/download/v#{version}/hexdb-v#{version}-x86_64-apple-darwin.tar.gz"
      sha256 "ffec530f2279cbf248107ba6f51e6b4ba9bb38d774773c62f9be559d0ccff22b"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/dreaminhex/hexdb/releases/download/v#{version}/hexdb-v#{version}-aarch64-unknown-linux-gnu.tar.gz"
      sha256 "b63337f6015964928b70402c9f0d1615ba5787dd3ed298a476d9feeaae1deeb4"
    end
    on_intel do
      url "https://github.com/dreaminhex/hexdb/releases/download/v#{version}/hexdb-v#{version}-x86_64-unknown-linux-gnu.tar.gz"
      sha256 "94e24792f9338e273c2ce2530be3f551fa3209845e2de3488ca71b2c6d21ae20"
    end
  end

  def install
    bin.install "hexdb_api", "hexdb"
    # `hexdb init` finds the admin UI here: ../share/hexdb/ui from the binaries.
    pkgshare.install "ui"
    lib.install Dir["odbc/*"]
    (etc/"hexdb").mkpath
    inreplace "hexdb.toml" do |s|
      s.gsub! 'path = "./data"', "path = \"#{var}/hexdb\""
      s.gsub! 'path = "./ui"', "path = \"#{opt_pkgshare}/ui\""
    end
    etc.install "hexdb.toml" => "hexdb/hexdb.toml" unless (etc/"hexdb/hexdb.toml").exist?
    doc.install "README.md", "MANUAL.md"
  end

  def post_install
    (var/"hexdb").mkpath
    local = etc/"hexdb/hexdb.local.toml"
    unless local.exist?
      key = Utils.safe_popen_read(bin/"hexdb", "secret").strip
      odie "hexdb secret printed no key" unless key.start_with?("base64:")
      # Created private (0600), so the key is never readable by others.
      File.open(local, File::WRONLY | File::CREAT | File::EXCL, 0600) { |f| f.write "[storage]\nencryption_key = \"#{key}\"\n" }
    end
  end

  def caveats
    <<~EOS
      Run HexDB as a background service, with its config in #{etc}/hexdb:
        brew services start hexdb
      Or run your own copy, with its config and data in your home folder:
        hexdb start

      Then open http://127.0.0.1:7700/ui/ and sign in as hexdbadmin. The generated
      password is in initial-admin-password.txt in the data folder
      (#{var}/hexdb for the service).

      Back up #{etc}/hexdb/hexdb.local.toml: it holds the encryption key.
      The ODBC driver is in #{opt_lib}.
    EOS
  end

  service do
    run [opt_bin/"hexdb_api", "--config", etc/"hexdb/hexdb.toml"]
    keep_alive true
    log_path var/"log/hexdb.log"
    error_log_path var/"log/hexdb.log"
  end

  test do
    assert_match "hexdb", shell_output("#{bin}/hexdb --version")
    assert_match "base64:", shell_output("#{bin}/hexdb secret")
  end
end
