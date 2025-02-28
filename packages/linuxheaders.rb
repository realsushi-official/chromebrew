require 'package'

class Linuxheaders < Package
  description 'Linux headers for Chrome OS.'
  homepage 'https://kernel.org/'
  @version = CREW_KERNEL_VERSION == '4.14' ? "#{CREW_KERNEL_VERSION}-1" : CREW_KERNEL_VERSION
  set_property('version', @version)
  license 'GPL-2'
  compatibility 'all'
  source_url 'https://chromium.googlesource.com/chromiumos/third_party/kernel.git'
  git_hashtag "chromeos-#{CREW_KERNEL_VERSION}"

  case CREW_KERNEL_VERSION
  when '3.8'
    binary_url({
      i686: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/linuxheaders/3.8_i686/linuxheaders-3.8-chromeos-i686.tpxz'
    })
    binary_sha256({
      i686: 'c16afcd95ebcffac67a026b724da19f498003ea80c13c87aeb613f09d412bb91'
    })
  when '4.14'
    binary_url({
      aarch64: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/linuxheaders/4.14-1_armv7l/linuxheaders-4.14-1-chromeos-armv7l.tpxz',
       armv7l: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/linuxheaders/4.14-1_armv7l/linuxheaders-4.14-1-chromeos-armv7l.tpxz',
       x86_64: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/linuxheaders/4.14-1_x86_64/linuxheaders-4.14-1-chromeos-x86_64.tpxz'
    })
    binary_sha256({
      aarch64: '75f253ac2cf0dd785ea8d9cdf9430d23d601ccc372e9f7afa95523a28273a340',
       armv7l: '75f253ac2cf0dd785ea8d9cdf9430d23d601ccc372e9f7afa95523a28273a340',
       x86_64: '5d58b327ca9bab5630f0df387a3036125e1f367e6c43cd551f4734ee3e634073'
    })
  when '5.10'
    binary_url({
      x86_64: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/linuxheaders/5.10_x86_64/linuxheaders-5.10-chromeos-x86_64.tar.zst'
    })
    binary_sha256({
      x86_64: '797e7a8369f613b50b049b2352f82d5842a2c9ae766d6d5b1165b90a528ac139'
    })
  end

  no_env_options
  no_fhs

  def self.install
    # make fails if it detects gold linker.
    FileUtils.mkdir_p('crew_bin')
    @workdir = Dir.pwd
    FileUtils.ln_sf "#{CREW_PREFIX}/bin/ld.bfd", "#{@workdir}/crew_bin/ld"
    system "PATH=#{@workdir}/crew_bin:$PATH make defconfig"
    system "PATH=#{@workdir}/crew_bin:$PATH make headers_install INSTALL_HDR_PATH=#{CREW_DEST_PREFIX}"
    Dir.chdir("#{CREW_DEST_PREFIX}/include") do
      system "for file in \$(find . -not -type d -name '.*'); do
                rm \${file};
              done"
    end
  end
end
