class VshOpensearch3 < Formula
  desc "Open source distributed and RESTful search engine"
  homepage "https://github.com/opensearch-project/OpenSearch"
  url "https://github.com/opensearch-project/OpenSearch/archive/refs/tags/3.2.0.tar.gz"
  sha256 "1f791778b8c86c1072181c810022f904613b9061568698ac014224ac71e12419"
  license "Apache-2.0"
  revision 3

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 sonoma: "ce7d4fa192e9faa123e5cd8d24cb25301064175ad7a2ae20333fcf2a0c3d32ce"
  end

  depends_on "gradle@8" => :build
  depends_on "openjdk"

  def cluster_name
    "opensearch3"
  end

  def install
    system "gradle", ":distribution:archives:no-jdk-darwin-tar:assemble", "-Dbuild.snapshot=false"

    mkdir "tar" do
      # Extract the package to the tar directory
      system "tar", "--strip-components=1", "-xf",
        Dir["../distribution/archives/no-jdk-darwin-tar/build/distributions/opensearch-*.tar.gz"].first

      # Install into package directory
      libexec.install "bin", "config", "lib", "modules", "agent"

      # Set up Opensearch for local development:
      inreplace "#{libexec}/config/opensearch.yml" do |s|
        # 1. Give the cluster a unique name
        s.gsub!(/#\s*cluster\.name: .*/, "cluster.name: #{cluster_name}")
        s.gsub!(/#\s*network\.host: .*/, "network.host: 127.0.0.1")
        s.gsub!(/#\s*http\.port: .*/, "http.port: 9223")

        s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/lib/#{name}/")
        s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/#{name}/")
      end

      inreplace "#{libexec}/config/jvm.options", %r{logs/gc.log}, "#{var}/log/#{name}/gc.log"

      config_file = "#{libexec}/config/opensearch.yml"
      open(config_file, "a") { |f| f.puts "transport.host: 127.0.0.1\ntransport.port: 9323\n" }
    end

      # add placeholder to avoid removal of empty directory
      touch "#{libexec}/config/jvm.options.d/.keepme"

    # Move config files into etc
    (etc/"#{name}").install Dir[libexec/"config/*"]
    (libexec/"config").rmtree

    (libexec/"bin/opensearch-plugin-update").write <<~EOS
        #!/bin/bash

        export JAVA_HOME="#{Formula["openjdk"].opt_libexec}/openjdk.jdk/Contents/Home"

        base_dir=$(dirname $0)
        PLUGIN_BIN=${base_dir}/opensearch-plugin

        for plugin in $(${PLUGIN_BIN} list); do
            "${PLUGIN_BIN}" remove "${plugin}"
            "${PLUGIN_BIN}" install "${plugin}"
        done
    EOS

    chmod 0755, libexec/"bin/opensearch-plugin-update"

    inreplace libexec/"bin/opensearch-env",
              "if [ -z \"$OPENSEARCH_PATH_CONF\" ]; then OPENSEARCH_PATH_CONF=\"$OPENSEARCH_HOME\"/config; fi",
              "if [ -z \"$OPENSEARCH_PATH_CONF\" ]; then OPENSEARCH_PATH_CONF=\"#{etc}/#{name}\"; fi"

    inreplace libexec/"bin/opensearch-env",
              "CDPATH=\"\"",
              "JAVA_HOME=\"#{Formula['openjdk'].opt_libexec}/openjdk.jdk/Contents/Home\"\nCDPATH=\"\""

    bin.env_script_all_files(libexec/"bin", JAVA_HOME: Formula["openjdk"].opt_prefix)
  end

  def post_install
    # Make sure runtime directories exist
    (var/"lib/#{name}").mkpath
    (var/"log/#{name}").mkpath
    ln_s etc/"#{name}", libexec/"config" unless (libexec/"config").exist?
    (var/"#{name}/plugins").mkpath
    ln_s var/"#{name}/plugins", libexec/"plugins" unless (libexec/"plugins").exist?
    (var/"opensearch/extensions").mkpath
    ln_s var/"opensearch/extensions", libexec/"extensions" unless (libexec/"extensions").exist?
    # fix test not being able to create keystore because of sandbox permissions
    system libexec/"bin/opensearch-keystore", "create" unless (etc/"#{name}/opensearch.keystore").exist?

    # run plugin update script
    system libexec/"bin/opensearch-plugin-update"
  end

  def caveats
    <<~EOS
      Data:    #{var}/lib/#{name}/
      Logs:    #{var}/log/#{name}/#{cluster_name}.log
      Plugins: #{var}/#{name}/plugins/
      Config:  #{etc}/#{name}/
    EOS
  end

  service do 
    run opt_libexec/"bin/opensearch"
    keep_alive false
    working_dir var
    log_path var/"log/vsh-opensearch3.log"
    error_log_path var/"log/vsh-opensearch3.log"
  end

  test do
    port = free_port
    (testpath/"data").mkdir
    (testpath/"logs").mkdir
    fork do
      exec bin/"opensearch", "-Ehttp.port=#{port}",
                                "-Epath.data=#{testpath}/data",
                                "-Epath.logs=#{testpath}/logs"
    end
    sleep 20
    output = shell_output("curl -s -XGET localhost:#{port}/")
    assert_equal "oss", JSON.parse(output)["version"]["build_flavor"]

    system "#{bin}/opensearch-plugin", "list"
  end
end
