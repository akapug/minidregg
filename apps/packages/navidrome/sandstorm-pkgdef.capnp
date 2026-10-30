@0xa9c8b7d6e5f40312;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "cvs53nmnfn463htz3yyyr8zunufczacrdg31n14j61n7g4dpeadh",
  manifest = (
    appTitle = (defaultText = "Navidrome"),
    appVersion = 2,
    appMarketingVersion = (defaultText = embed "version.txt"),
    actions = [
      (title = (defaultText = "New music library"), nounPhrase = (defaultText = "library"), command = .myCommand)
    ],
    continueCommand = .myCommand,
    metadata = (
      icons = (appGrid = .logo, grain = .logo, market = .logo, marketBig = .logo),
      website = "https://www.navidrome.org",
      codeUrl = "https://github.com/navidrome/navidrome",
      license = (openSource = gpl3),
      categories = [media],
      author = (upstreamAuthor = "Navidrome contributors"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Personal music streaming server"),
      changeLog = (defaultText = embed "changelog.md"),
    ),
  ),
  sourceMap = (searchPath = [(sourcePath = "rootfs")]),
  fileList = "sandstorm-files.list",
  alwaysInclude = ["opt/app", "usr", "etc", "bin", "lib", "lib64", "sandstorm-http-bridge"],
  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [(name = "manage", title = (defaultText = "manage"),
                      description = (defaultText = "allows adding music to the library"))],
      roles = [
        (title = (defaultText = "owner"), permissions = [true],
         verbPhrase = (defaultText = "can add music")),
        (title = (defaultText = "listener"), permissions = [false],
         verbPhrase = (defaultText = "can listen"), default = true)
      ],
    ),
  ),
);

const logo :Spk.Metadata.Icon = (svg = embed "navidrome.svg");

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "8000", "--", "/bin/bash", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "HOME", value = "/var"),
    (key = "SANDSTORM", value = "1"),
    (key = "TMPDIR", value = "/var/tmp")
  ]
);
