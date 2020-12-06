class VshMysql80 < Formula
  # .
  desc "Open source relational database management system"
  homepage "https://dev.mysql.com/doc/refman/8.0/en/"
  url "https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-boost-8.0.21.tar.gz"
  revision 7
  sha256 "37231a123372a95f409857364dc1deb196b6f2c0b1fe60cc8382c7686b487f11"
  license "GPL-2.0"

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 "24d5c31b85061d61e83088b4cedd4208d24f4ca8f4b68e9617e227993c8e70be" => :catalina
  end

  depends_on "cmake" => :build
  # GCC is not supported either, so exclude for El Capitan.
  depends_on macos: :sierra if DevelopmentTools.clang_build_version == 800
  depends_on "openssl@1.1"
  depends_on "protobuf"

  uses_from_macos "libedit"

  conflicts_with "mariadb", "percona-server",
    because: "mysql, mariadb, and percona install the same binaries"



  # https://bugs.mysql.com/bug.php?id=86711
  # https://github.com/Homebrew/homebrew-core/pull/20538
  fails_with :clang do
    build 800
    cause "Wrong inlining with Clang 8.0, see MySQL Bug #86711"
  end

  def datadir
    var/"#{name}"
  end

  def etcdir
    etc/name
  end

  def install
    # -DINSTALL_* are relative to `CMAKE_INSTALL_PREFIX` (`prefix`)
    args = %W[
      -DCMAKE_INSTALL_PREFIX=#{libexec}
      -DFORCE_INSOURCE_BUILD=1
      -DCOMPILATION_COMMENT=valet-sh
      -DINSTALL_DOCDIR=share/doc/#{name}
      -DINSTALL_INCLUDEDIR=include/mysql
      -DINSTALL_INFODIR=share/info
      -DINSTALL_MANDIR=share/man
      -DINSTALL_MYSQLSHAREDIR=share/mysql
      -DINSTALL_PLUGINDIR=lib/plugin
      -DMYSQL_DATADIR=#{datadir}
      -DSYSCONFDIR=#{etcdir}
      -DWITH_BOOST=boost
      -DWITH_EDITLINE=system
      -DWITH_SSL=#{Formula["openssl@1.1"].opt_prefix}
      -DWITH_PROTOBUF=system
      -DWITH_UNIT_TESTS=OFF
      -DENABLED_LOCAL_INFILE=1
      -DWITH_INNODB_MEMCACHED=ON
    ]

    system "cmake", ".", *std_cmake_args, *args
    system "make"
    system "make", "install"

    (bin/"mysql8.0").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysql --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mysqldump8.0").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysqldump --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mysqladmin8.0").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysqladmin --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS

    # Remove libssl copies as the binaries use the keg anyway and they create problems for other applications
    rm_rf lib/"libssl.dylib"
    rm_rf lib/"libssl.1.1.dylib"
    rm_rf lib/"libcrypto.1.1.dylib"
    rm_rf lib/"libcrypto.dylib"
    rm_rf lib/"plugin/libcrypto.1.1.dylib"
    rm_rf lib/"plugin/libssl.1.1.dylib"

    # Remove the tests directory
    rm_rf prefix/"mysql-test"

    # Don't create databases inside of the prefix!
    # See: https://github.com/Homebrew/homebrew/issues/4975
    rm_rf prefix/"data"

    (buildpath/"my.cnf").write <<~EOS
        !includedir #{etc}/#{name}/conf.d/
    EOS
    (buildpath/"mysqld.cnf").write <<~EOS
        [mysqld_safe]
        socket =
        nice		= 0

        [mysqld]
        #user		= mysql
        #pid-file	= /var/run/mysqld/mysql80.pid

        socket =

        bind-address		= 127.0.0.1
        port		= 3308
        basedir		= #{opt_libexec}
        datadir		= #{datadir}
        tmpdir		= /tmp
        lc-messages-dir	= #{opt_libexec}/share/mysql
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
    (buildpath/"mysqldump.cnf").write <<~EOS
        [mysqldump]
        user = root
        protocol=tcp
        port=3308
        host=127.0.0.1
        quick
        quote-names
        max_allowed_packet	= 16M
        default-character-set = utf8mb4
    EOS
    (buildpath/"mysql.cnf").write <<~EOS
        [mysql]
        user = root
        protocol=tcp
        port=3308
        host=127.0.0.1
        default-character-set = utf8mb4
    EOS

    # Move config files into etc
    (etc/"#{name}").install "my.cnf"
    (etc/"#{name}/conf.d").install "mysqld.cnf"
    (etc/"#{name}/conf.d").install "mysqldump.cnf"
    (etc/"#{name}/conf.d").install "mysql.cnf"
  end

  def post_install
    # Make sure log directory exists
    (var/"log/#{name}").mkpath

    # Make sure the datadir exists
    datadir.mkpath
    unless (datadir/"mysql/general_log.CSM").exist?
      ENV["TMPDIR"] = nil
      system libexec/"bin/mysqld", "--defaults-file=#{etc}/#{name}/my.cnf", "--user=#{ENV["USER"]}",
        "--basedir=#{prefix}", "--datadir=#{datadir}", "--tmpdir=/tmp", "--initialize-insecure"
    end
  end

  def caveats
    s = <<~EOS
      MySQL 8.0 is configured to only allow connections from 127.0.0.1 on port 3308 by default

      To connect run:
          mysql8.0 -uroot
    EOS
    s
  end

  plist_options :manual => "vsh-mysql80"

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
    # Expects datadir to be a completely clean dir, which testpath isn't.
    dir = Dir.mktmpdir
    system libexec/"bin/mysqld", "--initialize-insecure", "--user=#{ENV["USER"]}",
    "--basedir=#{prefix}", "--datadir=#{dir}", "--tmpdir=#{dir}"

    port = free_port
    pid = fork do
      exec bin/"mysqld", "--bind-address=127.0.0.1", "--datadir=#{dir}", "--port=#{port}"
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
