class VshElasticsearch2 < Formula
  desc "Distributed search & analytics engine"
  homepage "https://www.elastic.co/products/elasticsearch"
  url "https://download.elastic.co/elasticsearch/release/org/elasticsearch/distribution/tar/elasticsearch/2.4.6/elasticsearch-2.4.6.tar.gz"
  sha256 "5f7e4bb792917bb7ffc2a5f612dfec87416d54563f795d6a70637befef4cfc6f"
  license "Apache-2.0"
  revision 37

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 sonoma: "1efdbd7dd1e2166b092dabea968c46f23f1fb75c573cc4b51512057d72effef1"
  end

  depends_on "openjdk@8"

  def cluster_name
    "elasticsearch_#{ENV["USER"]}"
  end


  def install

    # Remove Windows files
    rm_f Dir["bin/*.bat"]
    rm_f Dir["bin/*.exe"]

    # Install everything else into package directory
    libexec.install "bin", "config", "lib", "modules"

#    inreplace libexec/"bin/elasticsearch-env",
#              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"$ES_HOME\"/config; fi",
#              "if [ -z \"$ES_PATH_CONF\" ]; then ES_PATH_CONF=\"#{etc}/#{name}\"; fi"

    # Set up Elasticsearch for local development:
    inreplace "#{libexec}/config/elasticsearch.yml" do |s|
      # 1. Give the cluster a unique name
      s.gsub!(/#\s*cluster\.name: .*/, "cluster.name: #{cluster_name}")
      s.gsub!(/#\s*network\.host: .*/, "network.host: 127.0.0.1")
      s.gsub!(/#\s*http\.port: .*/, "http.port: 9202")

      # 2. Configure paths
      s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/lib/#{name}/")
      s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/#{name}/")

    end

    config_file = "#{libexec}/config/elasticsearch.yml"
    open(config_file, "a") { |f|
        f.puts "index.number_of_shards: 1\n"
        f.puts "index.number_of_replicas: 0\n"
        f.puts "index.store.throttle.type: none\n"
        f.puts "node.local: true\n"
        f.puts "script.inline: on\n"
        f.puts "script.indexed: on\n"
    }

    # Move config files into etc
    (etc/"#{name}").install Dir[libexec/"config/*"]
    rm_f (libexec/"config")

    inreplace libexec/"bin/plugin",
              "CDPATH=\"\"",
              "JAVA_HOME=\"#{Formula['openjdk@8'].opt_libexec}/openjdk.jdk/Contents/Home\"\nCDPATH=\"\""

    inreplace libexec/"bin/elasticsearch",
              "CDPATH=\"\"",
              "JAVA_HOME=\"#{Formula['openjdk@8'].opt_libexec}/openjdk.jdk/Contents/Home\"\nCDPATH=\"\""
  end

  def post_install
    # Make sure runtime directories exist
    (var/"lib/#{name}").mkpath
    (var/"log/#{name}").mkpath
    ln_s etc/"#{name}", libexec/"config" unless (libexec/"config").exist?
    (var/"#{name}/plugins").mkpath
    ln_s var/"#{name}/plugins", libexec/"plugins" unless (libexec/"plugins").exist?
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
    assert_includes(stable.url, "-oss-")

    port = free_port
    system "#{bin}/elasticsearch-plugin", "list"
    pid = testpath/"pid"
    begin
      system "#{bin}/elasticsearch", "-d", "-p", pid, "-Epath.data=#{testpath}/data", "-Ehttp.port=#{port}"
      sleep 10
      system "curl", "-XGET", "localhost:#{port}/"
    ensure
      Process.kill(9, pid.read.to_i)
    end

    port = free_port
    (testpath/"config/elasticsearch.yml").write <<~EOS
      path.data: #{testpath}/data
      path.logs: #{testpath}/logs
      node.name: test-es-path-conf
      http.port: #{port}
    EOS

    cp etc/"elasticsearch/jvm.options", "config"
    cp etc/"elasticsearch/log4j2.properties", "config"

    ENV["ES_PATH_CONF"] = testpath/"config"
    pid = testpath/"pid"
    begin
      system "#{bin}/elasticsearch", "-d", "-p", pid
      sleep 10
      system "curl", "-XGET", "localhost:#{port}/"
      output = shell_output("curl -s -XGET localhost:#{port}/_cat/nodes")
      assert_match "test-es-path-conf", output
    ensure
      Process.kill(9, pid.read.to_i)
    end
  end
end
