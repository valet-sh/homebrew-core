class VshValkey8 < Formula
  desc "High-performance data structure server that primarily serves key/value workloads"
  homepage "https://valkey.io"
  url "https://github.com/valkey-io/valkey/archive/refs/tags/8.1.1.tar.gz"
  sha256 "3355fbd5458d853ab201d2c046ffca9f078000587ccbe9a6c585110f146ad2c5"
  revision 1
  license all_of: [
    "BSD-3-Clause",
    "BSD-2-Clause", # deps/jemalloc, deps/linenoise, src/lzf*
    "BSL-1.0", # deps/fpconv
    "MIT", # deps/lua
    any_of: ["CC0-1.0", "BSD-2-Clause"], # deps/hdr_histogram
  ]
  head "https://github.com/valkey-io/valkey.git", branch: "unstable"

  bottle do
    sha256 cellar: :any,                 ventura: "5c4a6688a325b9e0b251d52f06d7e5f5f66cc2b4eb28a27f954d76172c61e104"
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