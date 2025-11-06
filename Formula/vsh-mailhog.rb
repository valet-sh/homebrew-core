class VshMailhog < Formula
  desc "Web and API based SMTP testing tool"
  homepage "https://github.com/mailhog/MailHog"
  url "https://github.com/mailhog/MailHog/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "6227b566f3f7acbfee0011643c46721e20389eba4c8c2d795c0d2f4d2905f282"
  license "MIT"
  revision 6

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 sonoma: "a76320d174adfa517f8c0ebdcbd918df5a1581f0599f22d00c92c8e030da82cc"
  end

  depends_on "go" => :build

  def install
    ENV["GOPATH"] = buildpath
    ENV["GO111MODULE"] = "auto"

    path = buildpath/"src/github.com/mailhog/MailHog"
    path.install buildpath.children

    system "go", "build", *std_go_args(output: bin/"MailHog", ldflags: "-s -w"), path
  end

  service do
    run [
      opt_bin/"MailHog",
      "-api-bind-addr",
      "127.0.0.1:8025",
      "-smtp-bind-addr",
      "127.0.0.1:1025",
      "-ui-bind-addr",
      "127.0.0.1:8025",
    ]
    keep_alive true
    log_path var/"log/mailhog.log"
    error_log_path var/"log/mailhog.log"
  end

  test do
    address = "127.0.0.1:#{free_port}"
    fork { exec "#{bin}/MailHog", "-ui-bind-addr", address }
    sleep 2

    output = shell_output("curl --silent #{address}")
    assert_match "<title>MailHog</title>", output
  end
end