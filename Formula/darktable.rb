class Darktable < Formula
  desc "An open source photography workflow application and raw developer"
  homepage "https://www.darktable.org"
  url "https://github.com/darktable-org/darktable/releases/download/release-4.2.1/darktable-4.2.1.tar.xz"
  sha256 "603a39c6074291a601f7feb16ebb453fd0c5b02a6f5d3c7ab6db612eadc97bac"
  license "GPL-3.0"


  depends_on "cmake" => :build
  depends_on "curl"
  depends_on "desktop-file-utils" => :optional
  depends_on "exiv2"
  depends_on "glib"
  depends_on "gmic" => :optional
  depends_on "graphicsmagick" => :optional
  depends_on "gtk+3"
  depends_on "imagemagick" => :recommended
  depends_on "intltool" => "with-perl"
  depends_on "iso-codes" => :optional
  depends_on "json-glib"
  depends_on "lensfun"
  depends_on "libavif" => :optional
  depends_on "libgphoto2" => :recommended
  depends_on "libheif" => :recommended
  depends_on "libomp" => :optional
  depends_on "libsecret" => :optional
  depends_on "libsoup@2" => :optional
  depends_on "little-cms2"
  depends_on "llvm" => :build  # darktable crashed on load with llvm@12
  depends_on "lua@5.4"
  depends_on "luarocks" => :build
  depends_on "jpeg-xl" => :optional
  depends_on "osm-gps-map" => :optional
  depends_on "po4a"
  depends_on "portmidi" => :optional
  depends_on "pugixml"
  depends_on "perl" => :recommended
  depends_on "sdl2"
  # depends_on "sqlite"  # macOS provides sqlite


  def caveats
    <<~EOS
      Tested only on macOS Catalina with the MacOS11.1 SDK (installed by
      Command Line Tools for Xcode 12.4)

      Normally, Homebrew's BaseSDKLocator would choose to use the MacOS10.15
      SDK:
      https://github.com/Homebrew/brew/blob/master/Library/Homebrew/os/mac/sdk.rb#L14).
      But using this SDK somehow triggers a bug in
      /Library/Developer/CommandLineTools/usr/include/c++/v1/cmath's inclusion
      of math.h. We override this behavior to force loading of the unversioned
      SDK which is currently a symlink pointing to MacOS11.1.sdk.

      ImageMagick and GraphicsMagick should both fulfill the same requirement.
      "--with-graphicsmagick" implies "./build.sh --enable-graphicsmagick" and
      "--without-imagemagick" implies "./build.sh --disable-imagemagick".
      If not specified, building these features will depend on whether CMake
      can autodetect dependencies:
      https://github.com/darktable-org/darktable/blob/master/build.sh#L173-L176.
    EOS
  end

  def install
    kegs = ["curl", "lua@5.4", "sdl2"]
    ldflags = kegs.map { |k| "-L#{Formula[k].opt_lib}" }
    cppflags = kegs.map { |k| "-I#{Formula[k].opt_include}" }
    pkg_config_path = kegs.map { |k| Formula[k].opt_lib/"pkgconfig" }
    openssl_dir = Formula["openssl"].opt_prefix

    lua_dir = Formula['lua@5.4'].opt_prefix
    lua_tree = libexec/"luarocks"

    if MacOS.version >= :catalina
      # Force MacOSX (MacOS11.1 SDK). Otherwise the MacOSX10.15 SDK, which has
      # a cmath/math.h include path bug, is chosen.
      active_developer_dir = Pathname.new(`/usr/bin/xcode-select -print-path`.strip)
      sdkroot = active_developer_dir/'SDKs/MacOSX.sdk'
      sdkroot = sdkroot.exist? ? sdkroot : MacOS.sdk_path_if_needed
    end

    build_extra = []
    build_extra << "--enable-graphicsmagick" if build.with? "graphicsmagick"
    build_extra << "--disable-imagemagick" if build.without? "imagemagick"

    system "luarocks", "--lua-dir", lua_dir, "--tree", lua_tree, "--lua-version", "5.4", "install", "luasec", "OPENSSL_DIR=#{openssl_dir}"
    # 2.1.0-1 needed to avoid _lua_objlen error: https://stackoverflow.com/a/50499755
    system "luarocks", "--lua-dir", lua_dir, "--tree", lua_tree, "--lua-version", "5.4", "install", "lua-cjson", "2.1.0-1", "OPENSSL_DIR=#{openssl_dir}"

    with_env({ "LDFLAGS"          => ldflags.join(" "),
               "CPPFLAGS"         => cppflags.join(" "),
               "PKG_CONFIG_PATH"  => pkg_config_path.join(":"),
               "HOMEBREW_SDKROOT" => sdkroot
    }) do
      opoo "HOMEBREW_SDKROOT=#{sdkroot}"
      system "./build.sh --prefix #{libexec} --build-type Release --install #{build_extra.join(" ")}"
    end
    Dir[libexec/"bin/*"].each do |dt_bin|
      dt_path = Pathname.new(dt_bin)
      dt_name = dt_path.basename
      (bin/dt_name).write_env_script(dt_path, { LUA_PATH: lua_tree/'share/lua/5.4/?.lua;;', LUA_CPATH: lua_tree/'lib/lua/5.4/?.so;;' })
    end
  end

  def post_install
    ohai "Tools are in #{libexec/'share/darktable/tools'}"
  end

  test do
    assert_equal "this is darktable #{version}", shell_output("#{bin}/darktable --version | head -n 1").strip
  end
end
