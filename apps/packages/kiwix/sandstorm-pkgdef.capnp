@0xf1c2d3e4a5b60718;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "7xx4myv7aafdqtm4rh4fj3ju1eck9dfqnnjca3y6513gradphzv0",
  manifest = (
    appTitle = (defaultText = "Kiwix"),
    appVersion = 2,
    appMarketingVersion = (defaultText = embed "version.txt"),
    actions = [
      (title = (defaultText = "New Kiwix library"), nounPhrase = (defaultText = "library"), command = .myCommand)
    ],
    continueCommand = .myCommand,
    metadata = (
      icons = (appGrid = .logo, grain = .logo, market = .logo, marketBig = .logo),
      website = "https://kiwix.org",
      codeUrl = "https://github.com/kiwix/kiwix-tools",
      license = (openSource = gpl3),
      categories = [media],
      author = (upstreamAuthor = "Kiwix contributors"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Offline Wikipedia and more"),
      changeLog = (defaultText = embed "changelog.md"),
    ),
  ),
  sourceMap = (searchPath = [(sourcePath = "rootfs")]),
  fileList = "sandstorm-files.list",
  alwaysInclude = ["opt/app", "usr", "etc", "bin", "lib", "lib64", "sandstorm-http-bridge"],
  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [(name = "uploader", title = (defaultText = "uploader"),
                      description = (defaultText = "allows importing a ZIM library"))],
      roles = [
        (title = (defaultText = "owner"), permissions = [true],
         verbPhrase = (defaultText = "can import the library")),
        (title = (defaultText = "reader"), permissions = [false],
         verbPhrase = (defaultText = "can read the library"), default = true)
      ],
    ),
  ),
);

const logo :Spk.Metadata.Icon = (svg = embed "kiwix.svg");

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "8000", "--", "/bin/bash", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "HOME", value = "/var"),
    (key = "SANDSTORM", value = "1"),
    (key = "TMPDIR", value = "/var/tmp")
  ]
);
