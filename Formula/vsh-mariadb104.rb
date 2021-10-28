class VshMariadb104 < Formula
  desc "Drop-in replacement for MySQL"
  homepage "https://mariadb.org/"
  url "http://ftp.hosteurope.de/mirror/mariadb.org/mariadb-10.4.21/source/mariadb-10.4.21.tar.gz"
  sha256 "94dd2e6f5d286de8a7dccffe984015d4253a0568281c7440e772cfbe098a291d"
  license "GPL-2.0-only"
  revision 2

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 catalina: "4705aef3a3c8a57f0ed2a6e2fe4a585d0a266fd8e1fd70847def5ec585107dd0"
  end

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "groonga"
  depends_on "openssl@1.1"
  depends_on "pcre2"

  uses_from_macos "bzip2"
  uses_from_macos "ncurses"
  uses_from_macos "zlib"

  on_macos do
    patch :DATA
  end

  fails_with gcc: "5"

  def datadir
    var/"#{name}"
  end

  def tmpconfdir
    libexec/"config"
  end

  def install
    # Set basedir and ldata so that mysql_install_db can find the server
    # without needing an explicit path to be set. This can still
    # be overridden by calling --basedir= when calling.
    inreplace "scripts/mysql_install_db.sh" do |s|
      s.change_make_var! "basedir", "\"#{opt_libexec}\""
      s.change_make_var! "ldata", "\"#{datadir}\""
    end

    # Use brew groonga
    rm_r "storage/mroonga/vendor/groonga"

    # -DINSTALL_* are relative to prefix
    args = %W[
      -DCMAKE_INSTALL_PREFIX=#{libexec}
      -DMYSQL_DATADIR=#{datadir}
      -DINSTALL_INCLUDEDIR=include/mysql
      -DINSTALL_MANDIR=share/man
      -DINSTALL_DOCDIR=share/doc/#{name}
      -DINSTALL_INFODIR=share/info
      -DINSTALL_MYSQLSHAREDIR=share/mysql
      -DWITH_READLINE=yes
      -DWITH_SSL=yes
      -DWITH_UNIT_TESTS=OFF
      -DDEFAULT_CHARSET=utf8mb4
      -DDEFAULT_COLLATION=utf8mb4_general_ci
      -DINSTALL_SYSCONFDIR=#{etc}/#{name}
      -DCOMPILATION_COMMENT=Homebrew
    ]

    # disable TokuDB, which is currently not supported on macOS
    args << "-DPLUGIN_TOKUDB=NO"

    system "cmake", ".", *std_cmake_args, *args

    system "make"
    system "make", "install"

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

    (bin/"mariadb10.4").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysql --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mariadump10.4").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysqldump --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mariadmin10.4").write <<~EOS
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
        #pid-file	= /var/run/mysqld/mariadb104.pid

        socket =

        bind-address		= 127.0.0.1
        port		= 3317
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
        port=3317
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

    unless File.exist? "#{datadir}/mysql/mysql/user.frm"
      ENV["TMPDIR"] = nil
      system libexec/"bin/mysql_install_db", "--verbose", "--auth-root-authentication-method=normal", "--user=#{ENV["USER"]}",
        "--basedir=#{libexec}", "--datadir=#{datadir}", "--tmpdir=/tmp"
    end
  end

  def caveats
    s = <<~EOS
      MariaDB 10.4 is configured to only allow connections from 127.0.0.1 on port 3317 by default

      To connect run:
          mariadb10.4 -uroot
    EOS
    s
  end

  plist_options :manual => "vsh-mariadb104"

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

__END__
diff --git a/storage/mroonga/CMakeLists.txt b/storage/mroonga/CMakeLists.txt
index 555ab248751..cddb6f2f2a6 100644
--- a/storage/mroonga/CMakeLists.txt
+++ b/storage/mroonga/CMakeLists.txt
@@ -215,8 +215,7 @@ set(MYSQL_INCLUDE_DIRS
   "${MYSQL_REGEX_INCLUDE_DIR}"
   "${MYSQL_RAPIDJSON_INCLUDE_DIR}"
   "${MYSQL_LIBBINLOGEVENTS_EXPORT_DIR}"
-  "${MYSQL_LIBBINLOGEVENTS_INCLUDE_DIR}"
-  "${MYSQL_SOURCE_DIR}")
+  "${MYSQL_LIBBINLOGEVENTS_INCLUDE_DIR}")

 if(MRN_BUNDLED)
   set(MYSQL_PLUGIN_DIR "${INSTALL_PLUGINDIR}")nd