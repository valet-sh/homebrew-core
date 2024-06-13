class VshMariadb106 < Formula
  desc "Drop-in replacement for MySQL"
  homepage "https://mariadb.org/"
  url "https://archive.mariadb.org/mariadb-10.6.18/source/mariadb-10.6.18.tar.gz"
  sha256 "6898a1111f47130709e28ba2c7bd1a57e4bb57101f6e109e597d51e6d385cf18"
  license "GPL-2.0-only"
  revision 10

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 ventura: "c3d0202ceb7c2493a6628d2fa254bec20d90f0ca5115f126952b39c64760b645"
  end

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "groonga"
  depends_on "openssl@3"
  depends_on "pcre2"

  uses_from_macos "bzip2"
  uses_from_macos "krb5"
  uses_from_macos "libedit"
  uses_from_macos "libxcrypt"
  uses_from_macos "libxml2"
  uses_from_macos "ncurses"
  uses_from_macos "xz"
  uses_from_macos "zlib"
  fails_with gcc: "5"

  def datadir
    var/"#{name}"
  end

  def tmpconfdir
    libexec/"config"
  end

  patch :DATA

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
      -DWITH_SSL=yes
      -DWITH_UNIT_TESTS=OFF
      -DDEFAULT_CHARSET=utf8mb4
      -DDEFAULT_COLLATION=utf8mb4_general_ci
      -DINSTALL_SYSCONFDIR=#{etc}/#{name}
      -DCOMPILATION_COMMENT=valet.sh
      -DPLUGIN_ROCKSDB=NO
    ]

    system "cmake", ".", *std_cmake_args, *args

    system "make"
    system "make", "install"

    # Save space
    (libexec/"mysql-test").rmtree
    (libexec/"sql-bench").rmtree

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

    (bin/"mariadb10.6").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysql --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mariadump10.6").write <<~EOS
      #!/bin/bash
      #{libexec}/bin/mysqldump --defaults-file=#{etc}/#{name}/my.cnf "$@"
    EOS
    (bin/"mariaadmin10.6").write <<~EOS
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
        socket =

        bind-address		= 127.0.0.1
        port		= 3319
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
        port=3319
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
      MariaDB 10.6 is configured to only allow connections from 127.0.0.1 on port 3319 by default

      To connect run:
          mariadb10.6 -uroot
    EOS
    s
  end

  service do 
    run [libexec/"bin/mysqld_safe", "--defaults-file=#{etc}/vsh-mariadb106/my.cnf", "--datadir=#{var}/vsh-mariadb106"]
    keep_alive true
    working_dir var/"vsh-mariadb106"
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
diff --git a/sql/mysqld.cc b/sql/mysqld.cc
index cfc16209251c2..a9960400c17cd 100644
--- a/sql/mysqld.cc
+++ b/sql/mysqld.cc
@@ -2953,6 +2953,15 @@ static void start_signal_handler(void)
   DBUG_VOID_RETURN;
 }

+/** Called only from signal_hand function. */
+static void* exit_signal_handler()
+{
+    my_thread_end();
+    signal_thread_in_use= 0;
+    pthread_exit(0);  // Safety
+    return nullptr;  // Avoid compiler warnings
+}
+

 /** This threads handles all signals and alarms. */
 /* ARGSUSED */
@@ -3013,10 +3022,7 @@ pthread_handler_t signal_hand(void *arg __attribute__((unused)))
     if (abort_loop)
     {
       DBUG_PRINT("quit",("signal_handler: calling my_thread_end()"));
-      my_thread_end();
-      signal_thread_in_use= 0;
-      pthread_exit(0);				// Safety
-      return 0;                                 // Avoid compiler warnings
+      return exit_signal_handler();
     }
     switch (sig) {
     case SIGTERM:
@@ -3035,6 +3041,7 @@ pthread_handler_t signal_hand(void *arg __attribute__((unused)))
         PSI_CALL_delete_current_thread();
         my_sigset(sig, SIG_IGN);
         break_connect_loop(); // MIT THREAD has a alarm thread
+        return exit_signal_handler();
       }
       break;
     case SIGHUP: