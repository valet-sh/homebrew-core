class VshValkey8 < Formula
  desc "High-performance data structure server that primarily serves key/value workloads"
  homepage "https://valkey.io"
  url "https://github.com/valkey-io/valkey/archive/refs/tags/8.1.2.tar.gz"
  sha256 "747b272191c15c7387f4ad3b3e7eda16deb1cffc6425e0571547f54e4d2e3646"
  revision 3
  license all_of: [
    "BSD-3-Clause",
    "BSD-2-Clause", # deps/jemalloc, deps/linenoise, src/lzf*
    "BSL-1.0", # deps/fpconv
    "MIT", # deps/lua
    any_of: ["CC0-1.0", "BSD-2-Clause"], # deps/hdr_histogram
  ]

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 ventura: "1407f2aed73d5e8a2ce4b6348d5566330068dff980dcdaeff20258d43d917596"
  end

  depends_on "openssl@3"

  def vardir
    var/"#{name}"
  end

  def etcdir
    etc/name
  end

  def install
    system "make", "install", "PREFIX=#{libexec}", "CC=#{ENV.cc}", "BUILD_TLS=yes"

    (bin/"valkey8-cli").write <<~EOS
      #!/bin/bash
      exec #{libexec}/bin/valkey-cli -p 6380 "$@"
    EOS

    %w[run db/valkey log].each { |p| (vardir/p).mkpath }

    # Fix up default conf file to match our paths
    inreplace "valkey.conf" do |s|
      s.gsub! "/var/run/valkey_6379.pid", vardir/"run/valkey.pid"
      s.gsub! "dir ./", "dir #{vardir}/db/valkey/"
      s.gsub! "port 6379", "port 6380"
      s.sub!(/^bind .*$/, "bind 127.0.0.1 ::1")
    end

    etcdir.install "valkey.conf"
    etcdir.install "sentinel.conf" => "valkey-sentinel.conf"
  end

  service do
    run [opt_libexec/"bin/valkey-server", "#{etc}/vsh-valkey8/valkey.conf"]
    keep_alive true
    error_log_path "#{var}/vsh-valkey8/log/valkey.log"
    log_path "#{var}/log/vsh-valkey8/valkey.log"
    working_dir "#{var}/vsh-valkey8"
  end

end