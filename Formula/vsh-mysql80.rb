class VshMysql80 < Formula
  # .
  desc "Open source relational database management system"
  homepage "https://dev.mysql.com/doc/refman/8.0/en/"
  url "https://cdn.mysql.com/Downloads/MySQL-8.0/mysql-boost-8.0.40.tar.gz"
  sha256 "eb34a23d324584688199b4222242f4623ea7bca457a3191cd7a106c63a7837d9"
  license "GPL-2.0-only" => { with: "Universal-FOSS-exception-1.0" }
  revision 17

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 ventura: "219fe35ee5230722667d4faa57b423740fb03ab614d2504db43155da33f2dec0"
  end

  depends_on "bison" => :build
  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "abseil"
  depends_on "icu4c@76"
  depends_on "libevent"
  depends_on "libfido2"
  depends_on "lz4"
  depends_on "openssl@3"
  depends_on "protobuf"
  depends_on "zlib" # Zlib 1.2.13+
  depends_on "zstd"

  uses_from_macos "curl"
  uses_from_macos "cyrus-sasl"
  uses_from_macos "libedit"


  conflicts_with "mysql", "mariadb", "percona-server",
    because: "mysql, mariadb, and percona install the same binaries"

  fails_with :gcc do
    version "6"
    cause "Requires C++17"
  end

  # Patch out check for Homebrew `boost`.
   # This should not be necessary when building inside `brew`.
  # https://github.com/Homebrew/homebrew-test-bot/pull/820
  patch :DATA

  def datadir
    var/"#{name}"
  end

  def etcdir
    etc/name
  end

  def openssl_include_dir
    #{Formula["openssl@3"]"/include"
  end

  def install

    icu4c = deps.find { |dep| dep.name.match?(/^icu4c(@\d+)?$/) }
                .to_formula

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
      -DBISON_EXECUTABLE=#{Formula["bison"].opt_bin}/bison
      -DOPENSSL_ROOT_DIR=#{Formula["openssl@3"].opt_prefix}
      -DWITH_SYSTEM_LIBS=ON
      -DWITH_BOOST=boost
      -DWITH_EDITLINE=system
      -DWITH_FIDO=system
      -DWITH_ICU=#{icu4c.opt_prefix}
      -DWITH_LIBEVENT=system
      -DWITH_LZ4=system
      -DWITH_PROTOBUF=system
      -DWITH_SSL=system
      -DWITH_ZLIB=system
      -DWITH_ZSTD=system
      -DWITH_UNIT_TESTS=OFF
      -DWITH_INNODB_MEMCACHED=ON
    ]

    system "cmake", "-S", ".", "-B", "build", *std_cmake_args, *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"

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

__END__
diff --git a/CMakeLists.txt b/CMakeLists.txt
index 42e63d0..5d21cc3 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -1942,31 +1942,6 @@ MYSQL_CHECK_RAPIDJSON()
 MYSQL_CHECK_FIDO()
 MYSQL_CHECK_FIDO_DLLS()

-IF(APPLE)
-  GET_FILENAME_COMPONENT(HOMEBREW_BASE ${HOMEBREW_HOME} DIRECTORY)
-  IF(EXISTS ${HOMEBREW_BASE}/include/boost)
-    FOREACH(SYSTEM_LIB ICU LIBEVENT LZ4 PROTOBUF ZSTD FIDO)
-      IF(WITH_${SYSTEM_LIB} STREQUAL "system")
-        MESSAGE(FATAL_ERROR
-          "WITH_${SYSTEM_LIB}=system is not compatible with Homebrew boost\n"
-          "MySQL depends on ${BOOST_PACKAGE_NAME} with a set of patches.\n"
-          "Including headers from ${HOMEBREW_BASE}/include "
-          "will break the build.\n"
-          "Please use WITH_${SYSTEM_LIB}=bundled\n"
-          "or do 'brew uninstall boost' or 'brew unlink boost'"
-          )
-      ENDIF()
-    ENDFOREACH()
-  ENDIF()
-  # Ensure that we look in /usr/local/include or /opt/homebrew/include
-  FOREACH(SYSTEM_LIB ICU LIBEVENT LZ4 PROTOBUF ZSTD FIDO)
-    IF(WITH_${SYSTEM_LIB} STREQUAL "system")
-      INCLUDE_DIRECTORIES(SYSTEM ${HOMEBREW_BASE}/include)
-      BREAK()
-    ENDIF()
-  ENDFOREACH()
-ENDIF()
-
 IF(WITH_AUTHENTICATION_FIDO OR WITH_AUTHENTICATION_CLIENT_PLUGINS)
   IF(WITH_FIDO STREQUAL "system" AND
     NOT WITH_SSL STREQUAL "system")