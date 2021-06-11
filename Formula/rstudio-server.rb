class RstudioServer < Formula
  desc "Integrated development environment (IDE) for R"
  homepage "https://www.rstudio.com"
  head "https://github.com/rstudio/rstudio.git"
  stable do
    url "https://github.com/rstudio/rstudio/archive/refs/tags/v1.4.1717.tar.gz"
    sha256 "5934fa1de6a277a6cb6e62249c1c5b9703af992fcf1c2a4ba6b5cf2e5d51dd51"
    # patch the soci paths to use the brew-installed ones.
    patch :DATA
  end

  bottle do
    root_url "https://dl.bintray.com/brew-rtools/bottles-rtools"
    sha256 catalina: "11dcdb6e7a391bdecf0d7a38ad8f9ba507cb5ee7746b367bdb1c24b22c2b2e23"
  end

  if OS.linux?
    depends_on "patchelf" => :build
    depends_on "libedit"
    depends_on "ncurses"
    depends_on "util-linux" # for libuuid
    depends_on "linux-pam"
  end

  depends_on "ant" => :build
  depends_on "cmake" => :build
  depends_on "gcc" => :build
  depends_on "openjdk@8" => :build
  depends_on "boost-rstudio-server"
  depends_on "openssl@1.1"
  depends_on "soci-rstudio-server"
  depends_on "yaml-cpp"
  depends_on "postgresql" => :recommended
  depends_on "r" => :recommended

  resource "dictionaries" do
    url "https://s3.amazonaws.com/rstudio-buildtools/dictionaries/core-dictionaries.zip"
    sha256 "4341a9630efb9dcf7f215c324136407f3b3d6003e1c96f2e5e1f9f14d5787494"
  end

  resource "mathjax" do
    url "https://s3.amazonaws.com/rstudio-buildtools/mathjax-27.zip"
    sha256 "c56cbaa6c4ce03c1fcbaeb2b5ea3c312d2fb7626a360254770cbcb88fb204176"
  end

  if OS.linux?
    resource "pandoc" do
      url "https://s3.amazonaws.com/rstudio-buildtools/pandoc/2.11.4/pandoc-2.11.4-linux-amd64.tar.gz"
      sha256 "25e4055db5144289dc45e7c5fb3616ea5cf75f460eba337b65474d9fbc40c0fb"
    end
  elsif OS.mac?
    resource "pandoc" do
      url "https://s3.amazonaws.com/rstudio-buildtools/pandoc/2.11.4/pandoc-2.11.4-macOS.zip"
      sha256 "13b8597860afa6ab802993a684b340be3f31f4d2a06c50b6601f9e726cf76f71"
    end
  end

  if OS.linux?
    resource "node" do
      url "https://nodejs.org/dist/v10.19.0/node-v10.19.0-linux-x64.tar.gz"
      sha256 "36d90bc58f0418f31dceda5b18eb260019fcc91e59b0820ffa66700772a8804b"
    end
  elsif OS.mac?
    resource "node" do
      url "https://nodejs.org/dist/v10.19.0/node-v10.19.0-darwin-x64.tar.gz"
      sha256 "b16328570651be44213a2303c1f9515fc506e0a96a273806f71ed000e3ca3cb3"
    end
  end

  def which_linux_distribution
    if File.exist?("/etc/redhat-release") || File.exist?("/etc/centos-release")
      "rpm"
    else
      "debian"
    end
  end

  def install
    # Reduce memory usage below 4 GB for CI.
    if OS.linux? && ENV["CI"]
      ENV["MAKEFLAGS"] = "-j2"
    elsif OS.mac? && ENV["CI"]
      ENV["MAKEFLAGS"] = "-j4"
    end

    ENV["JAVA_HOME"] = Formula["openjdk@8"].opt_prefix

    unless build.head?
      ENV["RSTUDIO_VERSION_MAJOR"] = version.to_s.split(".")[0]
      ENV["RSTUDIO_VERSION_MINOR"] = version.to_s.split(".")[1]
      ENV["RSTUDIO_VERSION_PATCH"] = version.to_s.split(".")[2]
    end

    # remove CFLAGS and CXXFLAGS set by java requirement, they break boost library detection
    ENV["CFLAGS"] = ""
    ENV["CXXFLAGS"] = ""

    common_dir = buildpath/"dependencies/common"

    (common_dir/"dictionaries").install resource("dictionaries")
    (common_dir/"mathjax-27").install resource("mathjax")
    (common_dir/"node/10.19.0").install resource("node")

    resource("pandoc").stage do
      (common_dir/"pandoc/2.11.4/").install "bin/pandoc"
    end

    mkdir "build" do
      args = ["-DRSTUDIO_TARGET=Server", "-DCMAKE_BUILD_TYPE=Release"]
      args << "-DBoost_NO_BOOST_CMAKE=ON"
      args << "-DRSTUDIO_USE_SYSTEM_BOOST=Yes"
      args << "-DBoost_NO_SYSTEM_PATHS=On"
      args << "-DBOOST_ROOT=#{Formula["boost-rstudio-server"].opt_prefix}"
      args << "-DCMAKE_INSTALL_PREFIX=#{prefix}/rstudio-server"
      args << "-DCMAKE_CXX_FLAGS=-I#{Formula["openssl"].opt_include}"
      args << "-DRSTUDIO_CRASHPAD_ENABLED=0"
      args << "-DRSTUDIO_USE_SYSTEM_YAML_CPP=Yes"
      args << "-DRSTUDIO_TOOLS_ROOT=#{common_dir}"
      # this is the path to the brew-installed soci (see the patch at the end)
      args << "-DBREW_SOCI=#{Formula["soci-rstudio-server"].lib}"
      args << "-DCMAKE_OSX_SYSROOT=#{MacOS.sdk_path}" if OS.mac?

      linkerflags = "-DCMAKE_EXE_LINKER_FLAGS=-L#{Formula["openssl"].opt_lib}"
      linkerflags += " -L#{Formula["linux-pam"].opt_lib}" if OS.linux? && (build.with? "linux-pam")
      args << linkerflags
      args << "-DPAM_INCLUDE_DIR=#{Formula["linux-pam"].opt_include}" if build.with? "linux-pam"

      system "cmake", "..", *args
      system "make", "install"
    end

    bin.install_symlink prefix/"rstudio-server/bin/rserver"
    bin.install_symlink prefix/"rstudio-server/bin/rstudio-server"
    prefix.install_symlink prefix/"rstudio-server/extras"
  end

  def post_install
    # patch path to rserver
    Dir.glob(prefix/"extras/**/*") do |f|
      if File.file?(f) && !File.readlines(f).grep(/#{prefix/"rstudio-server/bin/rserver"}/).empty?
        inreplace f, /#{prefix/"rstudio-server/bin/rserver"}/, opt_bin/"rserver"
      end
    end
  end

  def caveats
    daemon = if OS.linux?
      if which_linux_distribution == "rpm"
        <<-EOS

        sudo cp #{opt_prefix}/extras/systemd/rstudio-server.redhat.service /etc/systemd/system/
        EOS
      else
        <<-EOS

        sudo cp #{opt_prefix}/extras/systemd/rstudio-server.service /etc/systemd/system/
        EOS
      end
    elsif OS.mac?
      <<-EOS

        If it is an upgrade or the plist file exists, unload the plist first
        sudo launchctl unload -w /Library/LaunchDaemons/com.rstudio.launchd.rserver.plist

        sudo cp #{opt_prefix}/extras/launchd/com.rstudio.launchd.rserver.plist /Library/LaunchDaemons/
        sudo launchctl load -w /Library/LaunchDaemons/com.rstudio.launchd.rserver.plist
      EOS
    end

    <<~EOS
      - To test run RStudio Server,
          #{opt_bin}/rserver --server-daemonize=0 --server-data-dir=/tmp/rserver

      - To complete the installation of RStudio Server
          1. register RStudio daemon#{daemon}
          2. install the PAM configuration
              sudo cp #{opt_prefix}/extras/pam/rstudio /etc/pam.d/

          3. sudo rstudio-server start

      - In default, only users with id >1000 are allowed to login. To relax the
        requirement, add the following line to the configuration file located
        at `/etc/rstudio/rserver.conf`

          auth-minimum-user-id=500
    EOS
  end

  test do
    system "#{bin}/rstudio-server", "version"
  end
end


__END__
diff --git a/src/cpp/CMakeLists.txt b/src/cpp/CMakeLists.txt
index df54994..927d357 100644
--- a/src/cpp/CMakeLists.txt
+++ b/src/cpp/CMakeLists.txt
@@ -405,7 +405,7 @@ endif()

 # find SOCI libraries
 if(UNIX)
-   set(SOCI_LIBRARY_DIR "${RSTUDIO_TOOLS_SOCI}/build/lib")
+   set(SOCI_LIBRARY_DIR "${BREW_SOCI}")
    if(NOT APPLE AND RSTUDIO_USE_SYSTEM_SOCI)
       set(SOCI_LIBRARY_DIR "/usr/lib")
    endif()
-
