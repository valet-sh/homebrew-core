class VshPhp85 < Formula
  desc "General-purpose scripting language"
  homepage "https://www.php.net/"
  # Should only be updated if the new version is announced on the homepage, https://www.php.net/
  url "https://www.php.net/distributions/php-8.5.1.tar.xz"
  mirror "https://fossies.org/linux/www/php-8.5.1.tar.xz"
  sha256 "3f5bf99ce81201f526d25e288eddb2cfa111d068950d1e9a869530054ff98815"
  license all_of: [
    "PHP-3.01"
  ]
  revision 5

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 sonoma: "a7d61e4ab497700c03a9cbeb9ecd7cb9d6b602f6ca8443f2659a6234ce4e11e4"
  end

  depends_on "bison" => :build
  depends_on "pkgconf" => :build
  depends_on "re2c" => :build
  depends_on "apr"
  depends_on "apr-util"
  depends_on "argon2"
  depends_on "autoconf"
  depends_on "capstone"
  depends_on "curl"
  depends_on "freetds"
  depends_on "gd"
  depends_on "gmp"
  depends_on "icu4c@78"
  depends_on "libpq"
  depends_on "libsodium"
  depends_on "libzip"
  depends_on "net-snmp"
  depends_on "oniguruma"
  depends_on "openldap"
  depends_on "openssl@3"
  depends_on "pcre2"
  depends_on "sqlite"
  depends_on "tidy-html5"
  depends_on "unixodbc"
  depends_on "webp"
  depends_on "imagemagick"

  uses_from_macos "cyrus-sasl" => :build
  uses_from_macos "bzip2"
  uses_from_macos "libedit"
  uses_from_macos "libffi"
  uses_from_macos "libxml2"
  uses_from_macos "libxslt"
  uses_from_macos "zlib"
  depends_on "gettext"

  resource "xdebug_module" do
    url "https://github.com/xdebug/xdebug/archive/3.5.0.tar.gz"
    sha256 "b10d27bc09f242004474f4cdb3736a27b0dae3f41a9bc92259493fc019f97d10"
  end

  resource "imagick_module" do
    url "https://github.com/Imagick/imagick/archive/refs/tags/3.8.1.tar.gz"
    sha256 "b0e9279ddf6e75a8c6b4068e16daec0475427dbca7ce2e144e30a51a88aa5ddc"
  end

  def install
    # buildconf required due to system library linking bug patch
    system "./buildconf", "--force"

    inreplace "sapi/fpm/php-fpm.conf.in", ";daemonize = yes", "daemonize = no"

    config_path = etc/"#{name}"
    # Prevent system pear config from inhibiting pear install
    (config_path/"pear.conf").delete if (config_path/"pear.conf").exist?

    # Prevent homebrew from hardcoding path to sed shim in phpize script
    ENV["lt_cv_path_SED"] = "sed"

    # Identify build provider in php -v output and phpinfo()
    ENV["PHP_BUILD_PROVIDER"] = "valet.sh"

    # system pkg-config missing
    if OS.mac?
      sdk_path = MacOS.sdk_for_formula(self).path
      ENV["SASL_CFLAGS"] = "-I#{sdk_path}/usr/include/sasl"
      ENV["SASL_LIBS"] = "-lsasl2"

      # Each extension needs a direct reference to the sdk path or it won't find the headers
      headers_path = "=#{sdk_path}/usr"
      gettext_path = "=#{Formula["gettext"].opt_prefix}"
    else
      ENV["BZIP_DIR"] = Formula["bzip2"].opt_prefix
    end

    # `_www` only exists on macOS.
    fpm_user = OS.mac? ? "_www" : "www-data"
    fpm_group = OS.mac? ? "_www" : "www-data"

    ENV["EXTENSION_DIR"] = "#{prefix}/lib/#{name}/20250925"
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
      --enable-bcmath
      --enable-calendar
      --enable-dba
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
      --enable-shmop
      --enable-soap
      --enable-sockets
      --enable-sysvmsg
      --enable-sysvsem
      --enable-sysvshm
      --with-bz2#{headers_path}
      --with-capstone
      --with-curl
      --with-external-gd
      --with-external-pcre
      --with-ffi
      --with-fpm-user=#{fpm_user}
      --with-fpm-group=#{fpm_group}
      --with-gettext#{gettext_path}
      --with-gmp=#{Formula["gmp"].opt_prefix}
      --with-iconv#{headers_path}
      --with-layout=GNU
      --with-ldap-sasl
      --with-ldap=#{Formula["openldap"].opt_prefix}
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
      --with-snmp=#{Formula["net-snmp"].opt_prefix}
      --with-sodium
      --with-sqlite3
      --with-tidy=#{Formula["tidy-html5"].opt_prefix}
      --with-unixODBC
      --with-xsl
      --with-zip
      --with-zlib
    ]

    if OS.mac?
      args << "--enable-dtrace"
    else
      args << "--disable-dtrace"
      args << "--without-ndbm"
      args << "--without-gdbm"
    end

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
      args = %W[
        --with-imagick=#{Formula["imagemagick"].opt_prefix}
      ]
      system "#{bin}/phpize#{bin_suffix}"
      system "./configure", "--with-php-config=#{bin}/php-config#{bin_suffix}", *args
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
    error_log_path var/"log/vsh-php85.log"
  end

  test do
    assert_match(/^Zend OPcache$/, shell_output("#{bin}/php -i"), "Zend OPCache extension not loaded")

    # Test related to libxml2 and https://github.com/Homebrew/homebrew-core/issues/28398
    require "utils/linkage"
    libpq = Formula["libpq"].opt_lib/shared_library("libpq")
    assert Utils.binary_linked_to_library?(bin/"php", libpq), "No linkage with Homebrew #{libpq.basename}!"

    system sbin/"php-fpm", "-t"
    system bin/"phpdbg", "-V"
    system bin/"php-cgi", "-m"

    port = free_port
    port_fpm = free_port
    expected_output = /^Hello world!$/

    (testpath/"index.php").write <<~PHP
      <?php
      echo 'Hello world!' . PHP_EOL;
      var_dump(ldap_connect());
      $session = new SNMP(SNMP::VERSION_1, '127.0.0.1', 'public');
      var_dump(@$session->get('sysDescr.0'));
    PHP

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

    (testpath/"httpd.conf").write <<~EOS
      #{main_config}
      LoadModule mpm_prefork_module lib/httpd/modules/mod_mpm_prefork.so
      LoadModule php_module #{lib}/httpd/modules/libphp.so
      <FilesMatch \\.(php|phar)$>
        SetHandler application/x-httpd-php
      </FilesMatch>
    EOS

    (testpath/"fpm.conf").write <<~INI
      [global]
      daemonize=no
      [www]
      listen = 127.0.0.1:#{port_fpm}
      pm = dynamic
      pm.max_children = 5
      pm.start_servers = 2
      pm.min_spare_servers = 1
      pm.max_spare_servers = 3
    INI

    (testpath/"httpd-fpm.conf").write <<~EOS
      #{main_config}
      LoadModule mpm_event_module lib/httpd/modules/mod_mpm_event.so
      LoadModule proxy_module lib/httpd/modules/mod_proxy.so
      LoadModule proxy_fcgi_module lib/httpd/modules/mod_proxy_fcgi.so
      <FilesMatch \\.(php|phar)$>
        SetHandler "proxy:fcgi://127.0.0.1:#{port_fpm}"
      </FilesMatch>
    EOS

    begin
      pid = spawn Formula["httpd"].opt_bin/"httpd", "-X", "-f", "#{testpath}/httpd.conf"
      sleep 10
      assert_match expected_output, shell_output("curl -s 127.0.0.1:#{port}")

      Process.kill("TERM", pid)
      Process.wait(pid)

      fpm_pid = spawn sbin/"php-fpm#{bin_suffix}", "-y", "fpm.conf"
      pid = spawn Formula["httpd"].opt_bin/"httpd", "-X", "-f", "#{testpath}/httpd-fpm.conf"
      sleep 10
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