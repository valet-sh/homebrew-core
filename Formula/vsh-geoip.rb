class VshGeoip < Formula
  desc "This library is for the GeoIP Legacy format (dat)"
  homepage "https://github.com/maxmind/geoip-api-c"
  url "https://github.com/maxmind/geoip-api-c/releases/download/v1.6.12/GeoIP-1.6.12.tar.gz"
  sha256 "1dfb748003c5e4b7fd56ba8c4cd786633d5d6f409547584f6910398389636f80"
  revision 2
  license "LGPL-2.1-or-later"
  head "https://github.com/maxmind/geoip-api-c.git", branch: "main"

  conflicts_with "geoip",
    because: "geoip has been disabled"

  bottle do
    root_url "https://github.com/valet-sh/homebrew-core/releases/download/bottles"
    sha256 sonoma: "55b3c25135ab842e1c89e1c92b83a403a0fb9e507c99ff49d3df7c7a7770d878"
  end

  resource "database" do
    url "https://src.fedoraproject.org/lookaside/pkgs/GeoIP/GeoIP.dat.gz/4bc1e8280fe2db0adc3fe48663b8926e/GeoIP.dat.gz"
    sha256 "7fd7e4829aaaae2677a7975eeecd170134195e5b7e6fc7d30bf3caf34db41bcd"
  end

  def install
    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--datadir=#{var}",
                          "--prefix=#{prefix}"
    system "make", "install"
  end

  def post_install
    geoip_data = Pathname.new "#{var}/GeoIP"
    geoip_data.mkpath

    # Since default data directory moved, copy existing DBs
    legacy_data = Pathname.new "#{HOMEBREW_PREFIX}/share/GeoIP"
    cp Dir["#{legacy_data}/*"], geoip_data if legacy_data.exist?

    full = Pathname.new "#{geoip_data}/GeoIP.dat"
    ln_s "GeoLiteCountry.dat", full if !full.exist? && !full.symlink?
    full = Pathname.new "#{geoip_data}/GeoIPCity.dat"
    ln_s "GeoLiteCity.dat", full if !full.exist? && !full.symlink?
  end

  test do
    resource("database").stage do
      output = shell_output("#{bin}/geoiplookup -f GeoIP.dat 8.8.8.8")
      assert_match "GeoIP Country Edition: US, United States", output
    end
  end
end