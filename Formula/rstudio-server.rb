class RstudioServer < Formula
  desc "Integrated development environment (IDE) for R"
  homepage "https://www.rstudio.com"
  head "https://github.com/rstudio/rstudio.git"
  stable do
    url "https://github.com/rstudio/rstudio/tarball/v2022.12.0+353"
    sha256 "941ca00902f5a7745680cd44cd0a81ebaa29f9264ac5e67b066d51f3bc9362cf"
    # patch the soci paths to use the brew-installed ones.
    patch :DATA
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
  depends_on "boost"
  depends_on "yaml-cpp-rstudio-server"
  depends_on "openssl@1.1"
  depends_on "soci-rstudio-server"
  depends_on "yaml-cpp"
  depends_on "postgresql@13" => :recommended
  depends_on "r" => :recommended

  resource "dictionaries" do
    url "https://s3.amazonaws.com/rstudio-buildtools/dictionaries/core-dictionaries.zip"
    sha256 "4341a9630efb9dcf7f215c324136407f3b3d6003e1c96f2e5e1f9f14d5787494"
  end

  resource "mathjax" do
    url "https://s3.amazonaws.com/rstudio-buildtools/mathjax-27.zip"
    sha256 "c56cbaa6c4ce03c1fcbaeb2b5ea3c312d2fb7626a360254770cbcb88fb204176"
  end

  resource "pandoc" do
    url "https://s3.amazonaws.com/rstudio-buildtools/pandoc/2.18/pandoc-2.18-macOS.zip"
    sha256 "55bd37ef2a3941a7af65f72e94dc8de4e9e4f179a93909d6ecc24c55a4ef4255"
  end

  resource "node" do
    url "https://nodejs.org/dist/v16.14.0/node-v16.14.0-darwin-x64.tar.gz"
    sha256 "26702ab17903ad1ea4e13133bd423c1176db3384b8cf08559d385817c9ca58dc"
  end

  resource "quarto" do
    url "https://github.com/quarto-dev/quarto-cli/releases/download/v1.2.269/quarto-1.2.269-macos.tar.gz"
    sha256 "4bf7f46ac2249ef8e78c33c988f792fe4c342599edf933c08d7cc722ea7c824d"
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
    (common_dir/"node/16.14.0").install resource("node")
    (common_dir/"quarto").install resource("quarto")

    resource("pandoc").stage do
      (common_dir/"pandoc/2.16.2/").install "bin/pandoc"
    end

    mkdir "build" do
      args = ["-DRSTUDIO_TARGET=Server", "-DCMAKE_BUILD_TYPE=Release"]
      args << "-DBoost_NO_BOOST_CMAKE=ON"
      args << "-DRSTUDIO_USE_SYSTEM_BOOST=Yes"
      args << "-DBoost_NO_SYSTEM_PATHS=On"
      args << "-DBOOST_ROOT=#{Formula["boost"].opt_prefix}"
      args << "-DCMAKE_INSTALL_PREFIX=#{prefix}/rstudio-server"
      args << "-DCMAKE_CXX_FLAGS=-I#{Formula["openssl"].opt_include}"
      args << "-DRSTUDIO_CRASHPAD_ENABLED=0"
      args << "-DRSTUDIO_USE_SYSTEM_YAML_CPP=Yes"
      args << "-DRSTUDIO_TOOLS_ROOT=#{common_dir}"
      # this is the path to the brew-installed soci (see the patch at the end)
      args << "-DBREW_SOCI=#{Formula["soci-rstudio-server"].lib}"
      # this is the path to the brew-installed yaml-cpp (see the patch at the end)
      args << "-DYAML_CPP_INCLUDE=#{Formula["yaml-cpp-rstudio-server"].include}"
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
diff --git a/CMakeGlobals.txt b/CMakeGlobals.txt
index de77b8d1ee..49c92da1da 100644
--- a/CMakeGlobals.txt
+++ b/CMakeGlobals.txt
@@ -280,7 +280,7 @@ endif()
 message(STATUS "Using RStudio tools root: ${RSTUDIO_TOOLS_ROOT}")

 # special install directories for apple desktop
-if (APPLE)
+if (APPLE AND RSTUDIO_DESKTOP)
    if (RSTUDIO_ELECTRON)
       set(RSTUDIO_INSTALL_BIN        RStudio.app/Contents/Resources/app/bin)
       set(RSTUDIO_INSTALL_SUPPORTING RStudio.app/Contents/Resources/app)
@@ -442,4 +442,3 @@ if(APPLE)
    endif()

 endif()
-
diff -git a/src/cpp/CMakeLists.txt b/src/cpp/CMakeLists.txt
index 4ff419e..21ec42c 100644
--- a/src/cpp/CMakeLists.txt
+++ b/src/cpp/CMakeLists.txt
@@ -222,14 +222,15 @@ else()
    # NOTE: defines the following CMake variables:
    # - YAML_CPP_INCLUDE_DIR
    # - YAML_CPP_LIBRARIES
-   find_package(yaml-cpp REQUIRED)
+   set(YAML_CPP_INCLUDE_DIR "${YAML_CPP_INCLUDE}")
+   set(YAML_CPP_LIBRARIES   "${YAML_CPP_INCLUDE}/../lib/libyaml-cpp.a")
 endif()

-if(NOT EXISTS "${YAML_CPP_INCLUDE_DIR}")
+if(NOT EXISTS "${YAML_CPP_INCLUDE}")
    message(FATAL_ERROR "yaml-cpp not found (re-run dependencies script to install)")
 endif()

-include_directories(SYSTEM "${YAML_CPP_INCLUDE_DIR}")
+include_directories(SYSTEM "${YAML_CPP_INCLUDE}")

 # determine whether we should statically link boost. we always do this
 # unless we are building a non-packaged build on linux (in which case
@@ -475,7 +476,7 @@ if(UNIX)
          message(FATAL_ERROR "Some or all SOCI libraries were not found. Ensure the SOCI dependency is installed and try again.")
       endif()
    else()
-      set(SOCI_LIBRARY_DIR "${RSTUDIO_TOOLS_SOCI}/build/lib")
+      set(SOCI_LIBRARY_DIR "${BREW_SOCI}")
       find_library(SOCI_CORE_LIB NAMES "libsoci_core.a" "soci_core" PATHS "${SOCI_LIBRARY_DIR}" NO_DEFAULT_PATH)
       find_library(SOCI_SQLITE_LIB NAMES "libsoci_sqlite3.a" "soci_sqlite3" PATHS "${SOCI_LIBRARY_DIR}" NO_DEFAULT_PATH)
       find_library(SOCI_POSTGRESQL_LIB NAMES "libsoci_postgresql.a" "soci_postgresql" PATHS "${SOCI_LIBRARY_DIR}" NO_DEFAULT_PATH)
diff --git a/src/cpp/core/include/core/Thread.hpp b/src/cpp/core/include/core/Thread.hpp
index 9ca7f33..df3a0ad 100644
--- a/src/cpp/core/include/core/Thread.hpp
+++ b/src/cpp/core/include/core/Thread.hpp
@@ -17,6 +17,7 @@
 #define CORE_THREAD_HPP

 #include <queue>
+#include <set>

 #include <boost/utility.hpp>
 #include <boost/function.hpp>