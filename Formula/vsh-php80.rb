class VshPhp80 < Formula
  desc "General-purpose scripting language"
  homepage "https://www.php.net/"
  url "https://github.com/shivammathur/php-src-backports/archive/c56202b2b1f37a474c0f779253487420311f2f42.tar.gz"
  version "8.0.30"
  sha256 "091e70a151ec18206aa15a69d774ea661b0d43d4ba3fbbb3f794a5e81773ffce"
  license "PHP-3.01"
  revision 564

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 sonoma: "345e4dd19e4fd00e28dfa3950f8c7a0ed073062301f292feaefbcf5741cf46ca"
  end

  depends_on "bison" => :build
  depends_on "pkgconf" => :build
  depends_on "re2c" => :build
  depends_on "apr"
  depends_on "apr-util"
  depends_on "argon2"
  depends_on "aspell"
  depends_on "autoconf"
  depends_on "curl"
  depends_on "freetds"
  depends_on "freetype"
  depends_on "gd"
  depends_on "gettext"
  depends_on "glib"
  depends_on "gmp"
  depends_on "icu4c@77"
  depends_on "jpeg"
  depends_on "libpng"
  depends_on "libyaml"
  depends_on "krb5"
  depends_on "libffi"
  depends_on "libpq"
  depends_on "libsodium"
  depends_on "libzip"
  depends_on "oniguruma"
  depends_on "openldap"
  depends_on "openssl@3"
  depends_on "pcre2"
  depends_on "sqlite"
  depends_on "tidy-html5"
  depends_on "unixodbc"
  depends_on "webp"
  depends_on "imagemagick"

  uses_from_macos "xz" => :build
  uses_from_macos "bzip2"
  uses_from_macos "libedit"
  uses_from_macos "libffi"
  uses_from_macos "libxml2"
  uses_from_macos "libxslt"
  uses_from_macos "zlib"

  depends_on "gcc" => :build # must never be a runtime dependency

  # https://github.com/Homebrew/homebrew-core/issues/235820
  # https://clang.llvm.org/docs/UsersManual.html#gcc-extensions-not-implemented-yet
  fails_with :clang do
    cause "Performs worse due to lack of general global register variables"
  end

  patch :DATA

  resource "xdebug_module" do
    url "https://github.com/xdebug/xdebug/archive/3.4.7.tar.gz"
    sha256 "6959726ee2bb99efd660796736801b198ec0847b6360230a8143ad5e2d2063c2"
  end

  resource "imagick_module" do
    url "https://github.com/Imagick/imagick/archive/refs/tags/3.5.1.tar.gz"
    sha256 "a70ccb298bb1f76d01e028d60cdfc787ffc14ab8355f61317e537f8c2a75c509"
  end

  def install
    # Work around for building with Xcode 15.3
    if DevelopmentTools.clang_build_version >= 1500
      ENV.append "CFLAGS", "-Wno-incompatible-function-pointer-types"
      ENV.append "LDFLAGS", "-lresolv"
    end

    ENV.append "CFLAGS", "-Wno-incompatible-pointer-types" if OS.mac? && ENV.compiler.to_s.start_with?("gcc")

    # Work around to support `icu4c` 75, which needs C++17.
    ENV["ICU_CXXFLAGS"] = "-std=c++17"

    # buildconf required due to system library linking bug patch
    system "./buildconf", "--force"

    config_path = etc/"#{name}"
    # Prevent system pear config from inhibiting pear install
    (config_path/"pear.conf").delete if (config_path/"pear.conf").exist?

    ENV["lt_cv_path_SED"] = "sed"

    ENV["PHP_BUILD_PROVIDER"] = "valet.sh"

    # system pkg-config missing
    ENV["KERBEROS_CFLAGS"] = " "
    if OS.mac?
      ENV["SASL_CFLAGS"] = "-I#{MacOS.sdk_path_if_needed}/usr/include/sasl"
      ENV["SASL_LIBS"] = "-lsasl2"
    else
      ENV["SQLITE_CFLAGS"] = "-I#{Formula["sqlite"].opt_include}"
      ENV["SQLITE_LIBS"] = "-lsqlite3"
      ENV["BZIP_DIR"] = Formula["bzip2"].opt_prefix
    end

    # Each extension that is built on Mojave needs a direct reference to the
    # sdk path or it won't find the headers
    headers_path = "=#{MacOS.sdk_path_if_needed}/usr"

    ENV["EXTENSION_DIR"] = "#{prefix}/lib/#{name}/20200930"
    ENV["PHP_PEAR_PHP_BIN"] = "#{bin}/php#{bin_suffix}"

    args = %W[
      --prefix=#{prefix}
      --localstatedir=#{var}
      --sysconfdir=#{config_path}
      --libdir=#{prefix}/lib/#{name}
      --includedir=#{prefix}/include/#{name}
      --datadir=#{prefix}/share/#{name}
      --with-config-file-path=#{config_path}
      --with-config-file-scan-dir=#{config_path}/conf.d
      --program-suffix=#{bin_suffix}
      --with-pear=#{pkgshare}/pear
      --with-os-sdkpath=#{MacOS.sdk_path_if_needed}
      --disable-intl
      --enable-bcmath
      --enable-calendar
      --enable-dba
      --enable-dtrace
      --enable-exif
      --enable-ftp
      --enable-fpm
      --enable-gd
      --enable-intl
      --enable-mbregex
      --enable-mbstring
      --enable-mysqlnd
      --enable-pcntl
      --enable-phpdbg
      --enable-phpdbg-readline
      --enable-phpdbg-webhelper
      --enable-shmop
      --enable-soap
      --enable-sockets
      --enable-sysvmsg
      --enable-sysvsem
      --enable-sysvshm
      --with-bz2#{headers_path}
      --with-curl
      --with-external-gd
      --with-external-pcre
      --with-ffi
      --with-fpm-user=_www
      --with-fpm-group=_www
      --with-freetype
      --with-gettext=#{Formula["gettext"].opt_prefix}
      --with-gmp=#{Formula["gmp"].opt_prefix}
      --with-iconv#{headers_path}
      --with-jpeg
      --with-kerberos
      --with-layout=GNU
      --with-ldap=#{Formula["openldap"].opt_prefix}
      --with-ldap-sasl
      --with-libxml
      --with-libedit
      --with-mhash#{headers_path}
      --with-mysql-sock=/tmp/mysql.sock
      --with-mysqli=mysqlnd
      --with-ndbm#{headers_path}
      --with-openssl
      --with-password-argon2=#{Formula["argon2"].opt_prefix}
      --with-pdo-dblib=#{Formula["freetds"].opt_prefix}
      --with-pdo-mysql=mysqlnd
      --with-pdo-odbc=unixODBC,#{Formula["unixodbc"].opt_prefix}
      --with-pdo-pgsql=#{Formula["libpq"].opt_prefix}
      --with-pdo-sqlite
      --with-pgsql=#{Formula["libpq"].opt_prefix}
      --with-pic
      --with-pspell=#{Formula["aspell"].opt_prefix}
      --with-sodium
      --with-sqlite3
      --with-tidy=#{Formula["tidy-html5"].opt_prefix}
      --with-unixODBC
      --with-webp
      --with-xmlrpc
      --with-xsl
      --with-zip
      --with-zlib
    ]

    system "./configure", *args
    system "make"
    system "make", "install"

    resource("xdebug_module").stage {
      system "#{bin}/phpize#{bin_suffix}"
      system "./configure", "--with-php-config=#{bin}/php-config#{bin_suffix}"
      system "make", "clean"
      system "make", "all"
      system "make", "install"
    }

    resource("imagick_module").stage {
      system "#{bin}/phpize#{bin_suffix}"
      system "./configure", "--with-php-config=#{bin}/php-config#{bin_suffix}"
      system "make", "clean"
      system "make", "all"
      system "make", "install"
    }

    # Use OpenSSL cert bundle
    openssl = Formula["openssl@3"]
    %w[development production].each do |mode|
      inreplace "php.ini-#{mode}", /; ?openssl\.cafile=/,
        "openssl.cafile = \"#{openssl.pkgetc}/cert.pem\""
      inreplace "php.ini-#{mode}", /; ?openssl\.capath=/,
        "openssl.capath = \"#{openssl.pkgetc}/certs\""
    end

    inreplace "sapi/fpm/www.conf" do |s|
      s.gsub!(/listen =.*/, "listen = /tmp/#{name}.sock")
    end

    config_files = {
      "php.ini-development"   => "php.ini",
      "sapi/fpm/php-fpm.conf" => "php-fpm.conf",
      "sapi/fpm/www.conf"     => "php-fpm.d/www.conf",
    }
    config_files.each_value do |dst|
      dst_default = config_path/"#{dst}.default"
      rm dst_default if dst_default.exist?
    end
    config_path.install config_files

    unless (var/"log/php-fpm#{bin_suffix}.log").exist?
      (var/"log").mkpath
      touch var/"log/php-fpm#{bin_suffix}.log"
    end

    mv "#{bin}/pecl", "#{bin}/pecl#{bin_suffix}"
    mv "#{bin}/pear", "#{bin}/pear#{bin_suffix}"
    mv "#{bin}/peardev", "#{bin}/peardev#{bin_suffix}"

    cd "ext/intl" do
      system "#{bin}/phpize#{bin_suffix}"
      if OS.mac?
        # rubocop:disable all
        ENV["CC"] = "/usr/bin/clang"
        ENV["CXX"] = "/usr/bin/clang++"
        # rubocop:enable all
      end
      system "./configure", "--with-php-config=#{bin}/php-config#{bin_suffix}"
      system "make"
      system "make", "install"
    end

  end

  def post_install

    # check if php extension dir (e.g. 20180731) exists and is not a symlink
    # only relevant when running "brew postinstall" manually
    if (lib/"#{name}/#{php_ext_dir}").exist? && !(lib/"#{name}/#{php_ext_dir}").symlink?
        unless (var/"#{name}/#{php_ext_dir}").exist?
            (var/"#{name}/#{php_ext_dir}").mkpath
        end

        Dir.glob(lib/"#{name}/#{php_ext_dir}/*") do |php_module|
            php_module_name = File.basename(php_module)
            mv "#{php_module}", var/"#{name}/#{php_ext_dir}/#{php_module_name}"
        end

        rm_r lib/"#{name}/#{php_ext_dir}"
        ln_s var/"#{name}/#{php_ext_dir}", lib/"#{name}/#{php_ext_dir}"
    end

    pear_prefix = pkgshare/"pear"

    puts "#{pear_prefix}"

    pear_files = %W[
      #{pear_prefix}/.depdblock
      #{pear_prefix}/.filemap
      #{pear_prefix}/.depdb
      #{pear_prefix}/.lock
    ]

    %W[
      #{pear_prefix}/.channels
      #{pear_prefix}/.channels/.alias
    ].each do |f|
      chmod 0755, f
      pear_files.concat(Dir["#{f}/*"])
    end

    chmod 0644, pear_files

    {
      "php_ini"  => etc/"#{name}/php.ini"
    }.each do |key, value|
      value.mkpath if /(?<!bin|man)_dir$/.match?(key)
      system bin/"pear#{bin_suffix}", "config-set", key, value, "system"
    end

    system bin/"pear#{bin_suffix}", "update-channels"

    %w[
      intl
      opcache
    ].each do |e|
      ext_config_path = etc/"#{name}/conf.d/ext-#{e}.ini"
      extension_type = (e == "opcache") ? "zend_extension" : "extension"
      if ext_config_path.exist?
        inreplace ext_config_path,
          /#{extension_type}=.*$/, "#{extension_type}=#{e}.so"
      else
        ext_config_path.write <<~EOS
          [#{e}]
          #{extension_type}="#{e}.so"
        EOS
      end
    end
  end

  def php_version
    version.to_s.split(".")[0..1].join(".")
  end

  def bin_suffix
    "#{php_version}"
  end

  def php_ext_dir
    extension_dir = Utils.popen_read("#{bin}/php-config#{bin_suffix} --extension-dir").chomp
    File.basename(extension_dir)
  end

  service do 
    php_version = @formula.version.to_s.split(".")[0..1].join(".")
    bin_suffix = php_version
  
    run ["#{opt_sbin}/php-fpm#{bin_suffix}", "--nodaemonize"]
    keep_alive true
    working_dir var
    error_log_path var/"log/vsh-php80.log"
  end

  test do
    assert_match /^Zend OPcache$/, shell_output("#{bin}/php -i"),
      "Zend OPCache extension not loaded"
    # Test related to libxml2 and
    # https://github.com/Homebrew/homebrew-core/issues/28398
    assert_includes MachO::Tools.dylibs("#{bin}/php"),
      "#{Formula["libpq"].opt_lib}/libpq.5.dylib"
    system "#{sbin}/php-fpm#{bin_suffix}", "-t"
    system "#{bin}/phpdbg#{bin_suffix}", "-V"
    system "#{bin}/php-cgi#{bin_suffix}", "-m"
    # Prevent SNMP extension to be added
    assert_no_match /^snmp$/, shell_output("#{bin}/php -m"),
      "SNMP extension doesn't work reliably with Homebrew on High Sierra"
    begin
      require "socket"

      server = TCPServer.new(0)
      port = server.addr[1]
      server_fpm = TCPServer.new(0)
      port_fpm = server_fpm.addr[1]
      server.close
      server_fpm.close

      expected_output = /^Hello world!$/
      (testpath/"index.php").write <<~EOS
        <?php
        echo 'Hello world!' . PHP_EOL;
        var_dump(ldap_connect());
      EOS
      main_config = <<~EOS
        Listen #{port}
        ServerName localhost:#{port}
        DocumentRoot "#{testpath}"
        ErrorLog "#{testpath}/httpd-error.log"
        ServerRoot "#{Formula["httpd"].opt_prefix}"
        PidFile "#{testpath}/httpd.pid"
        LoadModule authz_core_module lib/httpd/modules/mod_authz_core.so
        LoadModule unixd_module lib/httpd/modules/mod_unixd.so
        LoadModule dir_module lib/httpd/modules/mod_dir.so
        DirectoryIndex index.php
      EOS

      (testpath/"fpm.conf").write <<~EOS
        [global]
        daemonize=no
        [www]
        listen = 127.0.0.1:#{port_fpm}
        pm = dynamic
        pm.max_children = 5
        pm.start_servers = 2
        pm.min_spare_servers = 1
        pm.max_spare_servers = 3
      EOS

      (testpath/"httpd-fpm.conf").write <<~EOS
        #{main_config}
        LoadModule mpm_event_module lib/httpd/modules/mod_mpm_event.so
        LoadModule proxy_module lib/httpd/modules/mod_proxy.so
        LoadModule proxy_fcgi_module lib/httpd/modules/mod_proxy_fcgi.so
        <FilesMatch \\.(php|phar)$>
          SetHandler "proxy:fcgi://127.0.0.1:#{port_fpm}"
        </FilesMatch>
      EOS

      pid = fork do
        exec Formula["httpd"].opt_bin/"httpd", "-X", "-f", "#{testpath}/httpd.conf"
      end
      sleep 3

      assert_match expected_output, shell_output("curl -s 127.0.0.1:#{port}")

      Process.kill("TERM", pid)
      Process.wait(pid)

      fpm_pid = fork do
        exec sbin/"php-fpm#{bin_suffix}", "-y", "fpm.conf"
      end
      pid = fork do
        exec Formula["httpd"].opt_bin/"httpd", "-X", "-f", "#{testpath}/httpd-fpm.conf"
      end
      sleep 3

      assert_match expected_output, shell_output("curl -s 127.0.0.1:#{port}")
    ensure
      if pid
        Process.kill("TERM", pid)
        Process.wait(pid)
      end
      if fpm_pid
        Process.kill("TERM", fpm_pid)
        Process.wait(fpm_pid)
      end
    end
  end
end

__END__
diff --git a/ext/curl/interface.c b/ext/curl/interface.c
index 134de48d6fe..90f486dfe77 100644
--- a/ext/curl/interface.c
+++ b/ext/curl/interface.c
@@ -1453,11 +1453,11 @@ static int curl_fnmatch(void *ctx, const char *pattern, const char *string)
 /* }}} */

 /* {{{ curl_progress */
-static size_t curl_progress(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow)
+static int curl_progress(void *clientp, double dltotal, double dlnow, double ultotal, double ulnow)
 {
 	php_curl *ch = (php_curl *)clientp;
 	php_curl_progress *t = ch->handlers->progress;
-	size_t	rval = 0;
+	int rval = 0;

 #if PHP_CURL_DEBUG
 	fprintf(stderr, "curl_progress() called\n");
@@ -1817,8 +1817,8 @@ static void _php_curl_set_default_options(php_curl *ch)
 {
 	char *cainfo;

-	curl_easy_setopt(ch->cp, CURLOPT_NOPROGRESS,        1);
-	curl_easy_setopt(ch->cp, CURLOPT_VERBOSE,           0);
+	curl_easy_setopt(ch->cp, CURLOPT_NOPROGRESS,        1L);
+	curl_easy_setopt(ch->cp, CURLOPT_VERBOSE,           0L);
 	curl_easy_setopt(ch->cp, CURLOPT_ERRORBUFFER,       ch->err.str);
 	curl_easy_setopt(ch->cp, CURLOPT_WRITEFUNCTION,     curl_write);
 	curl_easy_setopt(ch->cp, CURLOPT_FILE,              (void *) ch);
@@ -1829,8 +1829,8 @@ static void _php_curl_set_default_options(php_curl *ch)
 #ifndef ZTS
 	curl_easy_setopt(ch->cp, CURLOPT_DNS_USE_GLOBAL_CACHE, 1);
 #endif
-	curl_easy_setopt(ch->cp, CURLOPT_DNS_CACHE_TIMEOUT, 120);
-	curl_easy_setopt(ch->cp, CURLOPT_MAXREDIRS, 20); /* prevent infinite redirects */
+	curl_easy_setopt(ch->cp, CURLOPT_DNS_CACHE_TIMEOUT, 120L);
+	curl_easy_setopt(ch->cp, CURLOPT_MAXREDIRS, 20L); /* prevent infinite redirects */

 	cainfo = INI_STR("openssl.cafile");
 	if (!(cainfo && cainfo[0] != '\0')) {
@@ -1841,7 +1841,7 @@ static void _php_curl_set_default_options(php_curl *ch)
 	}

 #ifdef ZTS
-	curl_easy_setopt(ch->cp, CURLOPT_NOSIGNAL, 1);
+	curl_easy_setopt(ch->cp, CURLOPT_NOSIGNAL, 1L);
 #endif
 }
 /* }}} */
@@ -2216,7 +2216,7 @@ static int _php_curl_setopt(php_curl *ch, zend_long option, zval *zvalue, bool i
 			lval = zval_get_long(zvalue);
 			if (lval == 1) {
 				php_error_docref(NULL, E_NOTICE, "CURLOPT_SSL_VERIFYHOST no longer accepts the value 1, value 2 will be used instead");
-				error = curl_easy_setopt(ch->cp, option, 2);
+				error = curl_easy_setopt(ch->cp, option, 2L);
 				break;
 			}
 		case CURLOPT_AUTOREFERER:
@@ -2377,7 +2377,7 @@ static int _php_curl_setopt(php_curl *ch, zend_long option, zval *zvalue, bool i
 				return 1;
 			}
 # endif
-			error = curl_easy_setopt(ch->cp, option, lval);
+			error = curl_easy_setopt(ch->cp, option, (long) lval);
 			break;
 		case CURLOPT_SAFE_UPLOAD:
 			if (!zend_is_true(zvalue)) {
@@ -2711,7 +2711,7 @@ static int _php_curl_setopt(php_curl *ch, zend_long option, zval *zvalue, bool i

 		case CURLOPT_FOLLOWLOCATION:
 			lval = zend_is_true(zvalue);
-			error = curl_easy_setopt(ch->cp, option, lval);
+			error = curl_easy_setopt(ch->cp, option, (long) lval);
 			break;

 		case CURLOPT_HEADERFUNCTION:
@@ -2729,7 +2729,7 @@ static int _php_curl_setopt(php_curl *ch, zend_long option, zval *zvalue, bool i
 					/* no need to build the mime structure for empty hashtables;
 					   also works around https://github.com/curl/curl/issues/6455 */
 					curl_easy_setopt(ch->cp, CURLOPT_POSTFIELDS, "");
-					error = curl_easy_setopt(ch->cp, CURLOPT_POSTFIELDSIZE, 0);
+					error = curl_easy_setopt(ch->cp, CURLOPT_POSTFIELDSIZE, 0L);
 				} else {
 					return build_mime_structure_from_hash(ch, zvalue);
 				}
@@ -2794,7 +2794,7 @@ static int _php_curl_setopt(php_curl *ch, zend_long option, zval *zvalue, bool i

 		case CURLOPT_POSTREDIR:
 			lval = zval_get_long(zvalue);
-			error = curl_easy_setopt(ch->cp, CURLOPT_POSTREDIR, lval & CURL_REDIR_POST_ALL);
+			error = curl_easy_setopt(ch->cp, CURLOPT_POSTREDIR, (long) (lval & CURL_REDIR_POST_ALL));
 			break;

 		/* the following options deal with files, therefore the open_basedir check
@@ -2829,11 +2829,11 @@ static int _php_curl_setopt(php_curl *ch, zend_long option, zval *zvalue, bool i
 			if (zend_is_true(zvalue)) {
 				curl_easy_setopt(ch->cp, CURLOPT_DEBUGFUNCTION, curl_debug);
 				curl_easy_setopt(ch->cp, CURLOPT_DEBUGDATA, (void *)ch);
-				curl_easy_setopt(ch->cp, CURLOPT_VERBOSE, 1);
+				curl_easy_setopt(ch->cp, CURLOPT_VERBOSE, 1L);
 			} else {
 				curl_easy_setopt(ch->cp, CURLOPT_DEBUGFUNCTION, NULL);
 				curl_easy_setopt(ch->cp, CURLOPT_DEBUGDATA, NULL);
-				curl_easy_setopt(ch->cp, CURLOPT_VERBOSE, 0);
+				curl_easy_setopt(ch->cp, CURLOPT_VERBOSE, 0L);
 			}
 			break;