class VshMysql80 < Formula
  # .
  desc "Open source relational database management system"
  homepage "https://dev.mysql.com/doc/refman/8.0/en/"
  url "https://downloads.mysql.com/archives/get/p/23/file/mysql-boost-8.0.34.tar.gz"
  sha256 "0b881a19bcef732cd4dbbfc8dfeb84eff61f5dfe0d9788d015d699733e0adf1f"
  revision 26
  license "GPL-2.0"

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 ventura: "5862487be723766d04251afb1ab67edd2d53920b01ed81357218186b355a1102"
  end

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "icu4c"
  depends_on "libevent"
  depends_on "lz4"
  depends_on "openssl@1.1"
  depends_on "protobuf@21"
  depends_on "zstd"
  depends_on "zlib" # Zlib 1.2.12+

  uses_from_macos "curl"
  uses_from_macos "cyrus-sasl"
  uses_from_macos "libedit"


  conflicts_with "mysql", "mariadb", "percona-server",
    because: "mysql, mariadb, and percona install the same binaries"

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
      -DWITH_SYSTEM_LIBS=ON
      -DWITH_BOOST=boost
      -DWITH_EDITLINE=system
      -DWITH_ICU=system
      -DWITH_LIBEVENT=system
      -DWITH_LZ4=system
      -DWITH_FIDO=bundled
      -DWITH_PROTOBUF=system
      -DWITH_SSL=/usr/local/opt/openssl@1.1
      -DWITH_ZLIB=system
      -DWITH_ZSTD=system
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

  service do 
    run [libexec/"bin/mysqld_safe", "--defaults-file=#{etc}/vsh-mysql80/my.cnf", "--datadir=#{var}/vsh-mysql80"]
    keep_alive true
    working_dir var/"vsh-mysql80"
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
