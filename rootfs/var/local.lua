-- Miss a lot of packages but it works (actually no for downloading but you know, i'm fuckikng tired lol)
return {
  ["idar-loom"] = {
    install_dir = "/",
    package_type = "explicit",
    installed_version = "4.1.0",
    dependencies = {},
    installed_at = 1777257557621,
    bin = {
      "boot/vmloomz",
    },
  },

  ["idar-boot"] = {
    install_dir = "/",
    package_type = "explicit",
    installed_version = "3.0.0",
    dependencies = {},
    installed_at = 1777257557621,
    bin = {
      "boot/MBR.lua",
      "boot/init",
    },
  },

  ["idar-pacman"] = {
    install_dir = "/",
    package_type = "explicit",
    installed_version = "3.0.0",
    dependencies = {
      ["clib"] = ">=1.0.0",
      ["crypto"] = ">=1.0.0",
      ["bignum"] = ">=1.0.0",
    },
    installed_at = 1777257557621,
    bin = {
      "bin/pacman",
    },
  },

  ["idar-coreutils"] = {
    install_dir = "/",
    package_type = "explicit",
    installed_version = "1.0.0",
    dependencies = {
      ["clib"] = ">=1.0.0",
    },
    installed_at = 1777257557621,
    bin = {
      "bin/cat",
      "bin/ls",
      "bin/mkdir",
      "bin/mv",
      "bin/rm",
      "bin/touch",
    },
  },

  ["idar-shell"] = {
    install_dir = "/",
    package_type = "explicit",
    installed_version = "3.0.0",
    dependencies = {
      ["clib"] = ">=1.0.0",
      ["coreutils"] = ">=1.0.0",
    },
    installed_at = 1777257557621,
    bin = {
      "bin/dsh",
    },
  },

  ["idar-clib"] = {
    install_dir = "/",
    package_type = "implicit",
    installed_version = "1.0.0",
    dependencies = {},
    installed_at = 1777257557621,
    bin = {
      "lib/Clib/stdio.lua",
      "lib/Clib/stdlib.lua",
      "lib/Clib/unistd.lua",
      "lib/Clib/fcntl.lua",
      "lib/Clib/pwd.lua",
    },
  },

  ["idar-bignum"] = {
    install_dir = "/",
    package_type = "implicit",
    installed_version = "4.0.0",
    dependencies = {},
    installed_at = 1777257557621,
    bin = {
      "lib/Bignum/bigNum.lua",
    },
  },

  ["idar-cryptolib"] = {
    install_dir = "/",
    package_type = "implicit",
    installed_version = "1.0.0",
    dependencies = {
      ["bignum"] = ">=4.0.0",
      ["clib"] = ">=1.0.0",
    },
    installed_at = 1777257557621,
    bin = {
      "lib/Crypto/chacha20.lua",
      "lib/Crypto/encoding.lua",
      "lib/Crypto/secp256k1_gtable.bin",
      "lib/Crypto/secp256k1.lua",
      "lib/Crypto/sha.lua",
    },
  },
}