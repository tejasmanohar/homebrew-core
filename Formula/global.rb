class Global < Formula
  desc "Source code tag system"
  homepage "https://www.gnu.org/software/global/"
  url "https://ftpmirror.gnu.org/global/global-6.5.4.tar.gz"
  mirror "https://ftp.gnu.org/gnu/global/global-6.5.4.tar.gz"
  sha256 "af16e0a686a46f759156cb685e25f345680703f43f93af1ce8d834caaf541da6"

  bottle do
    revision 2
    sha256 "b3210dcfc79345c62594110cca80ec252285ab149aa95214ca79000490d3b179" => :el_capitan
    sha256 "a747a41990ed2455483658672c971465a55bbfb99f3b1b6dfa24282cf6497e41" => :yosemite
    sha256 "776433a65c48183e5a1161ed57c375f9e150b7c6d8c4e8c2ad811dd71253ff69" => :mavericks
  end

  head do
    url ":pserver:anonymous:@cvs.savannah.gnu.org:/sources/global", using: :cvs

    depends_on "autoconf" => :build
    depends_on "automake" => :build
    depends_on "bison" => :build
    depends_on "flex" => :build
    ## gperf is provided by OSX Command Line Tools.
    depends_on "libtool" => :build
  end

  option "with-ctags", "Enable Exuberant Ctags as a plug-in parser"
  option "with-pygments", "Enable Pygments as a plug-in parser (should enable exuberent-ctags too)"
  option "with-sqlite3", "Use SQLite3 API instead of BSD/DB API for making tag files"

  deprecated_option "with-exuberant-ctags" => "with-ctags"

  depends_on "ctags" => :optional

  skip_clean "lib/gtags"

  resource "pygments" do
    url "https://pypi.python.org/packages/source/P/Pygments/Pygments-2.1.3.tar.gz"
    sha256 "88e4c8a91b2af5962bfa5ea2447ec6dd357018e86e94c7d14bd8cacbc5b55d81"
  end

  def install
    system "sh", "reconf.sh" if build.head?

    args = %W[
      --disable-dependency-tracking
      --prefix=#{prefix}
      --sysconfdir=#{etc}
    ]

    args << "--with-sqlite3" if build.with? "sqlite3"

    if build.with? "ctags"
      args << "--with-exuberant-ctags=#{Formula["ctags"].opt_bin}/ctags"
    end

    if build.with? "pygments"
      ENV.prepend_create_path "PYTHONPATH", libexec/"lib/python2.7/site-packages"
      pygments_args = %W[build install --prefix=#{libexec}]
      resource("pygments").stage { system "python", "setup.py", *pygments_args }
    end

    system "./configure", *args
    system "make", "install"

    if build.with? "pygments"
      bin.env_script_all_files(libexec/"bin", PYTHONPATH: ENV["PYTHONPATH"])
    end

    etc.install "gtags.conf"

    # we copy these in already
    cd share/"gtags" do
      rm %w[README COPYING LICENSE INSTALL ChangeLog AUTHORS]
    end
  end

  test do
    (testpath/"test.c").write <<-EOS.undent
       int c2func (void) { return 0; }
       void cfunc (void) {int cvar = c2func(); }")
    EOS
    if build.with?("pygments") || build.with?("ctags")
      (testpath/"test.py").write <<-EOS
        def py2func ():
             return 0
        def pyfunc ():
             pyvar = py2func()
      EOS
    end
    if build.with? "pygments"
      assert shell_output("#{bin}/gtags --gtagsconf=#{share}/gtags/gtags.conf --gtagslabel=pygments .")
      if build.with? "ctags"
        assert_match "test.c", shell_output("#{bin}/global -d cfunc")
        assert_match "test.c", shell_output("#{bin}/global -d c2func")
        assert_match "test.c", shell_output("#{bin}/global -r c2func")
        assert_match "test.py", shell_output("#{bin}/global -d pyfunc")
        assert_match "test.py", shell_output("#{bin}/global -d py2func")
        assert_match "test.py", shell_output("#{bin}/global -r py2func")
      else
        # Everything is a symbol in this case
        assert_match "test.c", shell_output("#{bin}/global -s cfunc")
        assert_match "test.c", shell_output("#{bin}/global -s c2func")
        assert_match "test.py", shell_output("#{bin}/global -s pyfunc")
        assert_match "test.py", shell_output("#{bin}/global -s py2func")
      end
      assert_match "test.c", shell_output("#{bin}/global -s cvar")
      assert_match "test.py", shell_output("#{bin}/global -s pyvar")
    end
    if build.with? "ctags"
      assert shell_output("#{bin}/gtags --gtagsconf=#{share}/gtags/gtags.conf --gtagslabel=exuberant-ctags .")
      # ctags only yields definitions
      assert_match "test.c", shell_output("#{bin}/global -d cfunc   # passes")
      assert_match "test.c", shell_output("#{bin}/global -d c2func  # passes")
      assert_match "test.py", shell_output("#{bin}/global -d pyfunc  # passes")
      assert_match "test.py", shell_output("#{bin}/global -d py2func # passes")
      assert_no_match(/test\.c/, shell_output("#{bin}/global -r c2func  # correctly fails"))
      assert_no_match(/test\.c/, shell_output("#{bin}/global -s cvar    # correctly fails"))
      assert_no_match(/test\.py/, shell_output("#{bin}/global -r py2func # correctly fails"))
      assert_no_match(/test\.py/, shell_output("#{bin}/global -s pyvar   # correctly fails"))
    end
    if build.with? "sqlite3"
      assert shell_output("#{bin}/gtags --sqlite3 --gtagsconf=#{share}/gtags/gtags.conf --gtagslabel=default .")
      assert_match "test.c", shell_output("#{bin}/global -d cfunc")
      assert_match "test.c", shell_output("#{bin}/global -d c2func")
      assert_match "test.c", shell_output("#{bin}/global -r c2func")
      assert_match "test.c", shell_output("#{bin}/global -s cvar")
    end
    # C should work with default parser for any build
    assert shell_output("#{bin}/gtags --gtagsconf=#{share}/gtags/gtags.conf --gtagslabel=default .")
    assert_match "test.c", shell_output("#{bin}/global -d cfunc")
    assert_match "test.c", shell_output("#{bin}/global -d c2func")
    assert_match "test.c", shell_output("#{bin}/global -r c2func")
    assert_match "test.c", shell_output("#{bin}/global -s cvar")
  end
end
