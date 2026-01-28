class VshGradle6 < Formula
  desc "Open-source build automation tool based on the Groovy and Kotlin DSL"
  homepage "https://www.gradle.org/"
  url "https://services.gradle.org/distributions/gradle-6.9.4-all.zip"
  sha256 "84b50e7b380e9dc9bbc81e30a8eb45371527010cf670199596c86875f774b8b0"
  license "Apache-2.0"
  revision 1

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 sonoma: "45e8e9317d4e22eb769abdc15b4e9ff97e2ee58db0991f0b1a1f34254630f478"
  end

  depends_on "openjdk@11"

  def install
    rm(Dir["bin/*.bat"])
    libexec.install %w[bin docs lib src]
    (bin/"gradle").write_env_script libexec/"bin/gradle", Language::Java.overridable_java_home_env("11")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/gradle --version")

    (testpath/"settings.gradle").write ""
    (testpath/"build.gradle").write <<~GRADLE
      println "gradle works!"
    GRADLE
    gradle_output = shell_output("#{bin}/gradle build --no-daemon")
    assert_includes gradle_output, "gradle works!"
  end
end