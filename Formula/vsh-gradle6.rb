class VshGradle6 < Formula
  desc "Open-source build automation tool based on the Groovy and Kotlin DSL"
  homepage "https://www.gradle.org/"
  url "https://services.gradle.org/distributions/gradle-6.9.4-all.zip"
  sha256 "84b50e7b380e9dc9bbc81e30a8eb45371527010cf670199596c86875f774b8b0"
  license "Apache-2.0"
  revision 1

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 sonoma: "55b3c25135ab842e1c89e1c92b83a403a0fb9e507c99ff49d3df7c7a7770d878"
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