class VshMariadb114 < Formula
  desc "Drop-in replacement for MySQL"
  homepage "https://mariadb.org/"
  url "https://archive.mariadb.org/mariadb-11.4.5/source/mariadb-11.4.5.tar.gz"
  sha256 "ff6595f8c482f9921e39b97fa1122377a69f0dcbd92553c6b9032cbf0e9b5354"
  license "GPL-2.0-only"
  revision 11

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 sonoma: "f817cb86065dc4ac58c85e9c59cb999550eabf3d6d3d8c11fb7014ba2a2ab90e"
  end

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "fmt" => :build
  depends_on "pkgconf" => :build
  depends_on "groonga"
  depends_on "lz4"
  depends_on "lzo"
  depends_on "openssl@3"
  depends_on "pcre2"
  depends_on "xz"
  depends_on "zstd"

  uses_from_macos "bzip2"
  uses_from_macos "krb5"
  uses_from_macos "libedit"
  uses_from_macos "libxcrypt"
  uses_from_macos "libxml2"
  uses_from_macos "ncurses"
  uses_from_macos "zlib"

  def datadir
    var/"#{name}"
  end

  def tmpconfdir
    libexec/"config"
  end

  # system libfmt patch, upstream pr ref, https://github.com/MariaDB/server/pull/3786
  patch do
    url "https://github.com/MariaDB/server/commit/b6a924b8478d2fab5d51245ff6719b365d7db7f4.patch?full_index=1"
    sha256 "77b65b35cf0166b8bb576254ac289845db5a8e64e03b41f1bf4b2045ac1cd2d1"
  end

  def install
    # Set basedir and ldata so that mysql_install_db can find the server
    # without needing an explicit path to be set. This can still
    # be overridden by calling --basedir= when calling.
    inreplace "scripts/mysql_install_db.sh" do |s|
      s.change_make_var! "basedir", "\"#{opt_libexec}\""
      s.change_make_var! "ldata", "\"#{datadir}\""
    end

    rm_r "storage/mroonga/vendor/groonga"
    rm_r "extra/wolfssl"
    rm_r "zlib"

    # -DINSTALL_* are relative to prefix
    args = %W[
      -DCMAKE_INSTALL_PREFIX=#{libexec}
      -DMYSQL_DATADIR=#{datadir}
      -DINSTALL_INCLUDEDIR=include/mysql
      -DINSTALL_MANDIR=share/man
      -DINSTALL_DOCDIR=share/doc/#{name}
      -DINSTALL_INFODIR=share/info
      -DINSTALL_MYSQLSHAREDIR=share/mysql
      -DWITH_LIBFMT=system
      -DWITH_PCRE=system
      -DWITH_SSL=system
      -DWITH_ZLIB=system
      -DWITH_UNIT_TESTS=OFF
      -DDEFAULT_CHARSET=utf8mb4
      -DDEFAULT_COLLATION=utf8mb4_general_ci
      -DINSTALL_SYSCONFDIR=#{etc}/#{name}
      -DCOMPILATION_COMMENT=valet.sh
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    ]

    system "cmake", "-S", ".", "-B", "_build", *std_cmake_args, *args
    system "cmake", "--build", "_build"
    system "cmake", "--install", "_build"

    # Save space
    rm_r libexec/"mariadb-test"
    rm_r libexec/"sql-bench"

    # Don't create databases inside of the prefix!
    # See: https://github.com/Homebrew/homebrew/issues/4975
    rm_rf prefix/"data"

    # Link the setup script into bin
    (libexec/"bin").install_symlink libexec/"scripts/mysql_install_db"

    # Save space
    #(prefix/"mysql-test").rmtree
    #(prefix/"sql-bench").rmtree

    # Link the setup script into bin
    #bin.install_symlink prefix/"scripts/mysql_install_db"

    # Fix up the control script and link into bin
    #inreplace "#{prefix}/support-files/mysql.server", /^(PATH=".*)(")/, "\\1:#{HOMEBREW_PREFIX}/bin\\2"

    #bin.install_symlink prefix/"support-files/mysql.server"

    #libexec.install "bin", "docs", "include", "lib", "man", "share"

    (bin/"mariadb11.4").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mariadb --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mariadump11.4").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mariadb-dump --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mariaadmin11.4").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mariadb-admin --defaults-file=#{etc}/#{name}/my.cnf "$@"
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
        socket =

        bind-address		= 127.0.0.1
        port		= 3329
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
        collation-server=utf8mb4_general_ci
    EOS
    (tmpconfdir/"mysqldump.cnf").write <<~EOS
        [mysqldump]
        user = root
        protocol=tcp
        port=3329
        host=127.0.0.1
        quick
        quote-names
        max_allowed_packet	= 16M
        default-character-set = utf8mb4
    EOS

    # move config files into etc
    rm_rf etc/"#{name}/my.cnf"
    (etc/"#{name}").install tmpconfdir/"my.cnf"
    (etc/"#{name}/conf.d").install tmpconfdir/"mysqld.cnf"
    (etc/"#{name}/conf.d").install tmpconfdir/"mysqldump.cnf"

  end

  def post_install
    (var/"log/#{name}").mkpath
    # make sure the datadir exists
    datadir.mkpath

        # Don't initialize database, it clashes when testing other MySQL-like implementations.
    return if ENV["HOMEBREW_GITHUB_ACTIONS"]

    unless File.exist? "#{datadir}/mysql/user.frm"
      ENV["TMPDIR"] = nil
      system libexec/"bin/mysql_install_db", "--verbose", "--auth-root-authentication-method=normal", "--user=#{ENV["USER"]}",
        "--basedir=#{libexec}", "--datadir=#{datadir}", "--tmpdir=/tmp"
    end
  end

  def caveats
    s = <<~EOS
      MariaDB 11.4 is configured to only allow connections from 127.0.0.1 on port 3329 by default

      To connect run:
          mariadb11.4 -uroot
    EOS
    s
  end

  service do 
    run [libexec/"bin/mariadbd-safe", "--defaults-file=#{etc}/vsh-mariadb114/my.cnf", "--datadir=#{var}/vsh-mariadb114"]
    keep_alive true
    working_dir var/"vsh-mariadb114"
  end

  test do
    # expects datadir to be a completely clean dir, which testpath isn't.
    dir = Dir.mktmpdir
    system libexec/"bin/mariadbd", "--initialize-insecure", "--user=#{ENV["USER"]}",
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
