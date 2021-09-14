class Darktable < Formula
  desc "An open source photography workflow application and raw developer"
  homepage "https://www.darktable.org"
  url "https://github.com/darktable-org/darktable/releases/download/release-3.6.0/darktable-3.6.0.tar.xz"
  sha256 "86bcd0184af38b93c3688dffd3d5c19cc65f268ecf9358d649fa11fe26c70a39"
  license "GPL-3.0"

  depends_on "cmake" => :build
  depends_on "curl"
  depends_on "exiv2"
  depends_on "gphoto2"
  depends_on "graphicsmagick"
  depends_on "intltool" => "with-perl"
  depends_on "json-glib"
  depends_on "llvm@11" => :build  # darktable crashes on load with 12
  depends_on "lua@5.3"
  depends_on "luarocks" => :build
  depends_on "po4a"
  depends_on "pugixml"

  depends_on "perl" => :recommended

  def install
    kegs = ["curl", "lua@5.3"]
    ldflags = kegs.map { |k| "-L#{Formula[k].opt_lib}" }
    cppflags = kegs.map { |k| "-I#{Formula[k].opt_include}" }
    pkg_config_path = kegs.map { |k| Formula[k].opt_lib/"pkgconfig" }
    openssl_dir = Formula["openssl"].opt_prefix

    lua_dir = Formula['lua@5.3'].opt_prefix
    lua_tree = libexec/"luarocks"

  system "luarocks", "--lua-dir", lua_dir, "--tree", lua_tree, "--lua-version", "5.3", "install", "luasec", "OPENSSL_DIR=#{openssl_dir}"
  # 2.1.0-1 needed to avoid _lua_objlen error: https://stackoverflow.com/a/50499755
  system "luarocks", "--lua-dir", lua_dir, "--tree", lua_tree, "--lua-version", "5.3", "install", "lua-cjson", "2.1.0-1", "OPENSSL_DIR=#{openssl_dir}"

    with_env({ "LDFLAGS"         => ldflags.join(" "),
               "CPPFLAGS"        => cppflags.join(" "),
               "PKG_CONFIG_PATH" => pkg_config_path.join(":")
    }) do
      system "./build.sh --prefix #{libexec} --build-type Release --install"
    end
    Dir[libexec/"bin/*"].each do |dt_bin|
      dt_path = Pathname.new(dt_bin)
      dt_name = dt_path.basename
      (bin/dt_name).write_env_script(dt_path, { LUA_PATH: lua_tree/'share/lua/5.3/?.lua;;', LUA_CPATH: lua_tree/'lib/lua/5.3/?.so;;' })
    end
  end

  def post_install
    ohai "Tools are in #{libexec/'share/darktable/tools'}"
  end

  test do
    assert_equal "this is darktable #{version}", shell_output("#{bin}/darktable --version | head -n 1").strip
  end
end
