class VshMysql57 < Formula
  # .
  desc "Open source relational database management system"
  homepage "https://dev.mysql.com/doc/refman/5.7/en/"
  url "https://cdn.mysql.com/Downloads/MySQL-5.7/mysql-5.7.31-macos10.14-x86_64.tar.gz"
  revision 2
  version "5.7.31"
  sha256 "0d949c4dda2d9bd3e2fd5d5068c14cda48c995bbe0c3da2f5334ff449126f6be"

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 catalina: "2a29fd641e63bfec0870d0f76132b4b306873e78930f47e80e2882a84d1953d3"
  end

  def datadir
    var/"#{name}"
  end

  def tmpconfdir
    libexec/"config"
  end

  def install

    libexec.install "bin", "docs", "include", "lib", "man", "share"

    (bin/"mysql5.7").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysql --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mysqldump5.7").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysqldump --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mysqladmin5.7").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysqladmin --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS

    tmpconfdir.mkpath
    (tmpconfdir/"my.cnf").write <<~EOS
        !includedir #{etc}/#{name}/conf.d/
    EOS
    (tmpconfdir/"mysqld.cnf").write <<~EOS
        [mysqld_safe]
        socket =
        nice		= 0

        [mysqld]
        #user		= mysql
        #pid-file	= /var/run/mysqld/mysql57.pid

        socket =

        bind-address		= 127.0.0.1
        port		= 3307
        basedir		= #{opt_libexec}
        datadir		= #{datadir}
        tmpdir		= /tmp
        lc-messages-dir	= #{opt_libexec}/share
        skip-external-locking

        key_buffer_size		= 16M
        max_allowed_packet	= 16M
        thread_stack		= 192K
        thread_cache_size       = 8
        myisam-recover-options  = BACKUP
        max_connections        = 200
        log_error = #{var}/log/#{name}/error.log
        max_binlog_size   = 100M

        character-set-server=utf8mb4
        collation-server=utf8mb4_unicode_ci
    EOS
    (tmpconfdir/"mysqldump.cnf").write <<~EOS
        [mysqldump]
        user = root
        protocol=tcp
        port=3307
        host=127.0.0.1
        quick
        quote-names
        max_allowed_packet	= 16M
        default-character-set = utf8mb4
    EOS

    # move config files into etc
    (etc/"#{name}").install tmpconfdir/"my.cnf"
    (etc/"#{name}/conf.d").install tmpconfdir/"mysqld.cnf"
    (etc/"#{name}/conf.d").install tmpconfdir/"mysqldump.cnf"

  end

  def post_install
    (var/"log/#{name}").mkpath
    # make sure the datadir exists
    datadir.mkpath
    unless (datadir/"mysql/general_log.CSM").exist?
      ENV["TMPDIR"] = nil
      system libexec/"bin/mysqld", "--defaults-file=#{etc}/#{name}/my.cnf", "--user=#{ENV["USER"]}",
        "--basedir=#{prefix}", "--datadir=#{datadir}", "--tmpdir=/tmp", "--initialize-insecure"
    end
  end

  def caveats
    s = <<~EOS
      MySQL is configured to only allow connections from localhost by default

      To connect run:
          mysql -uroot
    EOS
    s
  end

  plist_options :manual => "vsh-mysql57"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>KeepAlive</key>
        <true/>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{libexec}/bin/mysqld_safe</string>
          <string>--defaults-file=#{etc}/#{name}/my.cnf</string>
          <string>--datadir=#{datadir}</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>WorkingDirectory</key>
        <string>#{datadir}</string>
      </dict>
      </plist>
    EOS
  end

  test do
    # expects datadir to be a completely clean dir, which testpath isn't.
    dir = Dir.mktmpdir
    system libexec/"bin/mysqld", "--initialize-insecure", "--user=#{ENV["USER"]}",
    "--basedir=#{prefix}", "--datadir=#{dir}", "--tmpdir=#{dir}"

    port = free_port
    pid = fork do
      exec libexec/"bin/mysqld", "--bind-address=127.0.0.1", "--datadir=#{dir}", "--port=#{port}"
    end
    sleep 2

    output = shell_output("curl 127.0.0.1:#{port}")
    output.force_encoding("ASCII-8BIT") if output.respond_to?(:force_encoding)
    assert_match version.to_s, output
  ensure
    Process.kill(9, pid)
    Process.wait(pid)
  end
end
