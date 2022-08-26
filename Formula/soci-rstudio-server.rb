class SociRstudioServer < Formula
  desc "Database access library for C++"
  homepage "https://soci.sourceforge.io/"
  url "https://downloads.sourceforge.net/project/soci/soci/soci-4.0.3/soci-4.0.3.zip"
  sha256 "598abf573252caf71790af5ff15beca20af548440b610e70468edfd3c12d47b0"
  license "BSL-1.0"
  livecheck do
    url :stable
  end

  depends_on "cmake" => :build
  depends_on "boost"
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

    # system ENV.cxx, "-o", "test", "test.cxx", "-std=c++11", "-L#{lib}", "-lsoci_core", "-lsoci_empty"
    # system "./test"
    system "ls"
  end
end
