class VshOpensearch2 < Formula
  desc "Open source distributed and RESTful search engine"
  homepage "https://github.com/opensearch-project/OpenSearch"
  url "https://github.com/opensearch-project/OpenSearch/archive/2.4.1.tar.gz"
  sha256 "df87d5aac8b44aa08788394723d8d458b6bc3b0808aa5891bd9797959921c632"
  license "Apache-2.0"
  revision 2

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 big_sur: "b5cc5c3350c311d787e2ef567d2bfb53faeae7c72a6cd7a901291b4c06f3e464"
  end

  depends_on "gradle" => :build
  depends_on "openjdk@17"

  def cluster_name
    "opensearch2"
  end

 patch :DATA

  def install
    system "gradle", ":distribution:archives:no-jdk-darwin-tar:assemble", "-Dbuild.snapshot=false"

    mkdir "tar" do
      # Extract the package to the tar directory
      system "tar", "--strip-components=1", "-xf",
        Dir["../distribution/archives/no-jdk-darwin-tar/build/distributions/opensearch-*.tar.gz"].first

      # Install into package directory
      libexec.install "bin", "config", "lib", "modules"

      # Set up Opensearch for local development:
      inreplace "#{libexec}/config/opensearch.yml" do |s|
        # 1. Give the cluster a unique name
        s.gsub!(/#\s*cluster\.name: .*/, "cluster.name: #{cluster_name}")
        s.gsub!(/#\s*network\.host: .*/, "network.host: 127.0.0.1")
        s.gsub!(/#\s*http\.port: .*/, "http.port: 9222")

        s.sub!(%r{#\s*path\.data: /path/to.+$}, "path.data: #{var}/lib/#{name}/")
        s.sub!(%r{#\s*path\.logs: /path/to.+$}, "path.logs: #{var}/log/#{name}/")
      end

      inreplace "#{libexec}/config/jvm.options", %r{logs/gc.log}, "#{var}/log/#{name}/gc.log"

      config_file = "#{libexec}/config/opensearch.yml"
      open(config_file, "a") { |f| f.puts "transport.host: 127.0.0.1\ntransport.port: 9322\n" }
    end

      # add placeholder to avoid removal of empty directory
      touch "#{libexec}/config/jvm.options.d/.keepme"

    # Move config files into etc
    (etc/"#{name}").install Dir[libexec/"config/*"]
    (libexec/"config").rmtree

    (libexec/"bin/opensearch-plugin-update").write <<~EOS
        #!/bin/bash

        export JAVA_HOME="#{Formula["openjdk@17"].opt_libexec}/openjdk.jdk/Contents/Home"

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
              "JAVA_HOME=\"#{Formula['openjdk@17'].opt_libexec}/openjdk.jdk/Contents/Home\"\nCDPATH=\"\""

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

  plist_options :manual => "vsh-opensearch2"

  def plist
    <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
        <dict>
          <key>KeepAlive</key>
          <false/>
          <key>Label</key>
          <string>#{plist_name}</string>
          <key>ProgramArguments</key>
          <array>
            <string>#{opt_libexec}/bin/opensearch</string>
          </array>
          <key>EnvironmentVariables</key>
          <dict>
          </dict>
          <key>RunAtLoad</key>
          <true/>
          <key>WorkingDirectory</key>
          <string>#{var}</string>
          <key>StandardErrorPath</key>
          <string>#{var}/log/#{name}/opensearch.log</string>
          <key>StandardOutPath</key>
          <string>#{var}/log/#{name}/opensearch.log</string>
        </dict>
      </plist>
    EOS
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

__END__
--- a/buildSrc/src/main/java/org/opensearch/gradle/info/GlobalBuildInfoPlugin.java
+++ b/buildSrc/src/main/java/org/opensearch/gradle/info/GlobalBuildInfoPlugin.java
@@ -45,6 +45,7 @@ import org.gradle.api.provider.ProviderFactory;
 import org.gradle.internal.jvm.Jvm;
 import org.gradle.internal.jvm.inspection.JvmInstallationMetadata;
 import org.gradle.internal.jvm.inspection.JvmMetadataDetector;
+import org.gradle.jvm.toolchain.internal.InstallationLocation;
 import org.gradle.util.GradleVersion;

 import javax.inject.Inject;
@@ -52,6 +53,8 @@ import java.io.File;
 import java.io.FileInputStream;
 import java.io.IOException;
 import java.io.UncheckedIOException;
+import java.lang.invoke.MethodHandles;
+import java.lang.invoke.MethodType;
 import java.nio.charset.StandardCharsets;
 import java.nio.file.Files;
 import java.nio.file.Path;
@@ -196,7 +199,29 @@ public class GlobalBuildInfoPlugin implements Plugin<Project> {
     }

     private JvmInstallationMetadata getJavaInstallation(File javaHome) {
-        return jvmMetadataDetector.getMetadata(javaHome);
+        final InstallationLocation location = new InstallationLocation(javaHome, "Java home");
+
+        try {
+            try {
+                // The getMetadata(File) is used by Gradle pre-7.6
+                return (JvmInstallationMetadata) MethodHandles.publicLookup()
+                    .findVirtual(JvmMetadataDetector.class, "getMetadata", MethodType.methodType(JvmInstallationMetadata.class, File.class))
+                    .bindTo(jvmMetadataDetector)
+                    .invokeExact(location.getLocation());
+            } catch (NoSuchMethodException | IllegalAccessException ex) {
+                // The getMetadata(InstallationLocation) is used by Gradle post-7.6
+                return (JvmInstallationMetadata) MethodHandles.publicLookup()
+                    .findVirtual(
+                        JvmMetadataDetector.class,
+                        "getMetadata",
+                        MethodType.methodType(JvmInstallationMetadata.class, InstallationLocation.class)
+                    )
+                    .bindTo(jvmMetadataDetector)
+                    .invokeExact(location);
+            }
+        } catch (Throwable ex) {
+            throw new IllegalStateException("Unable to find suitable JvmMetadataDetector::getMetadata", ex);
+        }
     }

     private List<JavaHome> getAvailableJavaVersions(JavaVersion minimumCompilerVersion) {
@@ -206,7 +231,7 @@ public class GlobalBuildInfoPlugin implements Plugin<Project> {
             String javaHomeEnvVarName = getJavaHomeEnvVarName(Integer.toString(version));
             if (System.getenv(javaHomeEnvVarName) != null) {
                 File javaHomeDirectory = new File(findJavaHome(Integer.toString(version)));
-                JvmInstallationMetadata javaInstallation = jvmMetadataDetector.getMetadata(javaHomeDirectory);
+                JvmInstallationMetadata javaInstallation = getJavaInstallation(javaHomeDirectory);
                 JavaHome javaHome = JavaHome.of(version, providers.provider(() -> {
                     int actualVersion = Integer.parseInt(javaInstallation.getLanguageVersion().getMajorVersion());
                     if (actualVersion != version) {