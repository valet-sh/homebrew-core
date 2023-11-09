class VshElasticsearch8 < Formula
  desc "Distributed search & analytics engine"
  homepage "https://www.elastic.co/products/elasticsearch"
  url "https://github.com/elastic/elasticsearch/archive/v8.1.2.tar.gz"
  sha256 "9e6a4af0c1d5c8887f5f5216f8066d6e96eadf5cc919296f2040858bfc4bd920"
  revision 18
  license "Apache-2.0"

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 ventura: "7b3cb163c9906f5d00377336d8000529765ede4e7dccfebadaa204a059768750"
  end

  depends_on "gradle@6" => :build
  depends_on "openjdk@17"

  def cluster_name
    "elasticsearch8"
  end

  def install
    ENV["ES_PATH_CONF"] = #{Formula["openjdk@17"]
    system "./gradlew", ":distribution:archives:darwin-tar:assemble", "-Dbuild.snapshot=false", "-Dlicense.key=./x-pack/plugin/core/snapshot.key"

    mkdir "tar" do
      # Extract the package to the tar directory
      system "tar", "--strip-components=1", "-xf",
        Dir["../distribution/archives/darwin-tar/build/distributions/elasticsearch-*.tar.gz"].first

      # Install into package directory
      libexec.install "bin", "config", "lib", "modules"

      # Set up Elasticsearch for local development:
      inreplace "#{libexec}/config/elasticsearch.yml" do |s|
        # 1. Give the cluster a unique name
        s.gsub!(/#\s*cluster\.name: .*/, "cluster.name: #{cluster_name}")
        s.gsub!(/#\s*network\.host: .*/, "network.host: 127.0.0.1")
        s.gsub!(/#\s*http\.port: .*/, "http.port: 9208")

        s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/lib/#{name}/")
        s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/#{name}/")
      end

      inreplace "#{libexec}/config/jvm.options", %r{logs/gc.log}, "#{var}/log/#{name}/gc.log"

      config_file = "#{libexec}/config/elasticsearch.yml"
      open(config_file, "a") { |f| f.puts "transport.host: 127.0.0.1\ntransport.port: 9308\nxpack.security.enabled: false\n"}
    end


    # Move config files into etc
    (etc/"#{name}").install Dir[libexec/"config/*"]
    (libexec/"config").rmtree

    (libexec/"bin/elasticsearch-plugin-update").write <<~EOS
        #!/bin/bash

        base_dir=$(dirname $0)
        PLUGIN_BIN=${base_dir}/elasticsearch-plugin

        for plugin in $(${PLUGIN_BIN} list); do
            "${PLUGIN_BIN}" remove "${plugin}"
            "${PLUGIN_BIN}" install "${plugin}"
        done
    EOS

    chmod 0755, libexec/"bin/elasticsearch-plugin-update"

    inreplace libexec/"bin/elasticsearch-env",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"$ES_HOME\"/config; fi",
              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"#{etc}/#{name}\"; fi"

    inreplace libexec/"bin/elasticsearch-env",
              "CDPATH=\"\"",
              "ES_JAVA_HOME=\"#{Formula['openjdk@17'].opt_libexec}/openjdk.jdk/Contents/Home\"\nCDPATH=\"\""

    bin.env_script_all_files(libexec/"bin", JAVA_HOME: Formula["openjdk@17"].opt_prefix)
  end

  def post_install
    # Make sure runtime directories exist
    (var/"lib/#{name}").mkpath
    (var/"log/#{name}").mkpath
    ln_s etc/"#{name}", libexec/"config" unless (libexec/"config").exist?
    (var/"#{name}/plugins").mkpath
    ln_s var/"#{name}/plugins", libexec/"plugins" unless (libexec/"plugins").exist?
    # fix test not being able to create keystore because of sandbox permissions
    system libexec/"bin/elasticsearch-keystore", "create" unless (etc/"#{name}/elasticsearch.keystore").exist?

    # run plugin update script
    system libexec/"bin/elasticsearch-plugin-update"
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
    run opt_libexec/"bin/elasticsearch"
    keep_alive false
    working_dir var
    log_path var/"log/elasticsearch.log"
    error_log_path var/"log/elasticsearch.log"
  end

  test do
    port = free_port
    (testpath/"data").mkdir
    (testpath/"logs").mkdir
    fork do
      exec bin/"elasticsearch", "-Ehttp.port=#{port}",
                                "-Epath.data=#{testpath}/data",
                                "-Epath.logs=#{testpath}/logs"
    end
    sleep 20
    output = shell_output("curl -s -XGET localhost:#{port}/")
    assert_equal "oss", JSON.parse(output)["version"]["build_flavor"]

    system "#{bin}/elasticsearch-plugin", "list"
  end
end
