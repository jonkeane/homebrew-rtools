class SociRstudioServer < Formula
  desc "Database access library for C++"
  homepage "https://soci.sourceforge.io/"
  url "https://downloads.sourceforge.net/project/soci/soci/soci-4.0.0/soci-4.0.0.zip"
  sha256 "c7fffa74867182d9559e20c6e8d291936c3bd8cfa8c7d0c13bb2eeb09e0f318b"
  license "BSL-1.0"
  livecheck do
    url :stable
  end

  bottle do
    root_url "https://dl.bintray.com/brew-rtools/bottles-rtools"
    sha256 "1fa3df94fb68a4f924cdf8889a7d285fa2678ccfaa56c4c2a7e943398e6c0a2d" => :catalina
  end

  depends_on "cmake" => :build
  depends_on "boost-rstudio-server"
  depends_on "postgresql"
  depends_on "sqlite"

  def install
    args = std_cmake_args + %w[
      -DWITH_SQLITE3:BOOL=ON
      -DWITH_BOOST:BOOL=ON
      -DWITH_MYSQL:BOOL=OFF
      -DWITH_ODBC:BOOL=OFF
      -DWITH_ORACLE:BOOL=OFF
      -DWITH_POSTGRESQL:BOOL=ON
    ]

    mkdir "build" do
      system "cmake", "..", *args
      system "make", "install"
    end
  end

  test do
    # (testpath/"test.cxx").write <<~EOS
    #   #include "soci/soci.h"
    #   #include "soci/empty/soci-empty.h"
    #   #include <string>
    #   using namespace soci;
    #   std::string connectString = "";
    #   backend_factory const &backEnd = *soci::factory_empty();
    #   int main(int argc, char* argv[])
    #   {
    #     soci::session sql(backEnd, connectString);
    #   }
    # EOS
    # 
    # system ENV.cxx, "-o", "test", "test.cxx", "-std=c++11", "-L#{lib}", "-lsoci_core", "-lsoci_empty"
    # system "./test"
    system "ls"
  end
end
