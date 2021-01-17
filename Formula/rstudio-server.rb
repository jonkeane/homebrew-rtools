class RstudioServer < Formula
  desc "Integrated development environment (IDE) for R"
  homepage "https://www.rstudio.com"
  head "https://github.com/rstudio/rstudio.git"
  stable do
    url "https://github.com/rstudio/rstudio/archive/v1.4.1103.tar.gz"
    sha256 "e448aaaf7ac7f4fd97197250762bfd28195c71abfd67db6f952463dea552be4c"
    # patch the soci paths to use the brew-installed ones.
    patch :DATA
  end

  bottle do
    root_url "https://dl.bintray.com/brew-rtools/bottles-rtools"
    cellar :any
    sha256 "394e40ce11c4d4aaeae3a1f7840b9a68bb6dece0ed7db2b44aaacbe2cdecbb25" => :catalina
  end

  if OS.linux?
    depends_on "patchelf" => :build
    depends_on "libedit"
    depends_on "ncurses"
    depends_on "util-linux" # for libuuid
    depends_on "linux-pam"
  end

  depends_on "adoptopenjdk" => :build if ENV["CI"] && OS.linux?
  depends_on "ant" => :build
  if OS.linux?
    depends_on "boost-rstudio-server"
  elsif OS.mac?
    depends_on "boost-rstudio-server" => :build
  end
  depends_on "cmake" => :build
  depends_on "gcc" => :build
  depends_on "openjdk" => :build
  depends_on "openssl@1.1"
  depends_on "soci-rstudio-server"
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
      url "https://s3.amazonaws.com/rstudio-buildtools/pandoc/2.11.2/pandoc-2.11.2-linux-amd64.tar.gz"
      sha256 "25e4055db5144289dc45e7c5fb3616ea5cf75f460eba337b65474d9fbc40c0fb"
    end
  elsif OS.mac?
    resource "pandoc" do
      url "https://s3.amazonaws.com/rstudio-buildtools/pandoc/2.11.2/pandoc-2.11.2-macOS.zip"
      sha256 "e256ad5ae298fa303f55d48fd40b678367a6f34108a037ce5d76bdc6cfca6258"
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
      (common_dir/"pandoc/2.11.2/").install "bin/pandoc"
    end

    mkdir "build" do
      args = ["-DRSTUDIO_TARGET=Server", "-DCMAKE_BUILD_TYPE=Release"]
      args << "-DRSTUDIO_USE_SYSTEM_BOOST=No"
      args << "-DBoost_NO_SYSTEM_PATHS=On"
      args << "-DBOOST_ROOT=#{Formula["boost-rstudio-server"].opt_prefix}"
      args << "-DCMAKE_INSTALL_PREFIX=#{prefix}/rstudio-server"
      args << "-DCMAKE_CXX_FLAGS=-I#{Formula["openssl"].opt_include}"
      args << "-DRSTUDIO_CRASHPAD_ENABLED=0"
      # this is the path to the brew-installed soci (see the patch at the end)
      args << "-DBREW_SOCI=#{Formula["soci-rstudio-server"].lib}"
      args << "-DBOOST_RSTUDIO_BREW_LIB=#{Formula["boost-rstudio-server"].lib}"
      args << "-DCMAKE_OSX_SYSROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk" if OS.mac?

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
index df54994..e512cb9 100644
--- a/src/cpp/CMakeLists.txt
+++ b/src/cpp/CMakeLists.txt
@@ -225,9 +225,9 @@ list(APPEND BOOST_LIBS
 # UNIX BOOST
 if(UNIX)
    # prefer static link to our custom built version
-   set(RSTUDIO_TOOLS_BOOST /opt/rstudio-tools/boost/boost_1_69_0)
+   set(RSTUDIO_TOOLS_BOOST "${BOOST_RSTUDIO_BREW_LIB}")
    if(NOT RSTUDIO_USE_SYSTEM_BOOST AND EXISTS ${RSTUDIO_TOOLS_BOOST})
-      add_definitions(-DRSTUDIO_BOOST_NAMESPACE=rstudio_boost)
+      add_definitions(-DRSTUDIO_BOOST_NAMESPACE=boost)

       # find headers
       set(Boost_USE_STATIC_LIBS ON)
@@ -405,7 +405,7 @@ endif()

 # find SOCI libraries
 if(UNIX)
-   set(SOCI_LIBRARY_DIR "${RSTUDIO_TOOLS_SOCI}/build/lib")
+   set(SOCI_LIBRARY_DIR "${BREW_SOCI}")
    if(NOT APPLE AND RSTUDIO_USE_SYSTEM_SOCI)
       set(SOCI_LIBRARY_DIR "/usr/lib")
    endif()
@@ -622,4 +622,3 @@ else()
    endif()

 endif()
-
