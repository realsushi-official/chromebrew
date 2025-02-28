require 'package'

class Py3_libxml2 < Package
  description 'Libxml2-python provides access to libxml2 and libxslt in Python.'
  homepage 'https://gitlab.gnome.org/GNOME/libxml2/'
  @_ver = '2.10.3'
  version "#{@_ver}-py3.10"
  license 'MIT'
  compatibility 'all'
  source_url 'https://gitlab.gnome.org/GNOME/libxml2/-/archive/v2.10.3/libxml2-v2.10.3.tar.bz2'
  source_sha256 '302bbb86400b8505bebfbf7b3d1986e9aa05073198979f258eed4be481ff5f83'

  binary_url({
    aarch64: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/py3_libxml2/2.10.3-py3.10_armv7l/py3_libxml2-2.10.3-py3.10-chromeos-armv7l.tar.zst',
     armv7l: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/py3_libxml2/2.10.3-py3.10_armv7l/py3_libxml2-2.10.3-py3.10-chromeos-armv7l.tar.zst',
       i686: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/py3_libxml2/2.10.3-py3.10_i686/py3_libxml2-2.10.3-py3.10-chromeos-i686.tar.zst',
     x86_64: 'https://gitlab.com/api/v4/projects/26210301/packages/generic/py3_libxml2/2.10.3-py3.10_x86_64/py3_libxml2-2.10.3-py3.10-chromeos-x86_64.tar.zst'
  })
  binary_sha256({
    aarch64: '78aa7d4890fe6890dfa4d61d285a193ba57d4856db0bd31037c8f0ec563debcd',
     armv7l: '78aa7d4890fe6890dfa4d61d285a193ba57d4856db0bd31037c8f0ec563debcd',
       i686: '58b5d28a139656758a015d580943a8a6a049e31526d21e09e57aee8358100ee3',
     x86_64: 'e66f9d4928223c33cbd1ae060f39da55b87ff1a4cb4ded49272650b97481c4cd'
  })

  depends_on 'libxml2'
  depends_on 'libxslt'
  depends_on 'py3_setuptools' => :build
  depends_on 'glibc' # R
  depends_on 'zlibpkg' # R

  def self.build
    system 'autoreconf -fiv'
    system "#{CREW_ENV_OPTIONS} ./configure #{CREW_OPTIONS}"
    Dir.chdir('python') do
      system "python3 setup.py build #{PY3_SETUP_BUILD_OPTIONS}"
    end
  end

  def self.install
    Dir.chdir('python') do
      system "python3 setup.py install #{PY_SETUP_INSTALL_OPTIONS_NO_SVEM}"
    end
  end
end
