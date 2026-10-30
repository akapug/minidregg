@0xb4d5e6f708192a3b;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "cd6fk64x5ndeem7ya2t3qfjkjsjjhts5y2eg54jpdy0g0whtwx40",
  manifest = (
    appTitle = (defaultText = "Firefly III"),
    appVersion = 2,
    appMarketingVersion = (defaultText = embed "version.txt"),
    actions = [
      (title = (defaultText = "New Firefly III"), nounPhrase = (defaultText = "ledger"), command = .myCommand)
    ],
    continueCommand = .myCommand,
    metadata = (
      icons = (appGrid = .logo, grain = .logo, market = .logo, marketBig = .logo),
      website = "https://www.firefly-iii.org",
      codeUrl = "https://github.com/firefly-iii/firefly-iii",
      license = (openSource = agpl3),
      categories = [office],
      author = (upstreamAuthor = "James Cole"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Personal finance manager"),
      changeLog = (defaultText = embed "changelog.md"),
    ),
  ),
  sourceMap = (searchPath = [(sourcePath = "rootfs")]),
  fileList = "sandstorm-files.list",
  alwaysInclude = ["opt/app", "usr", "etc", "bin", "lib", "lib64", "sandstorm-http-bridge"],
  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [(name = "edit", title = (defaultText = "edit"),
                      description = (defaultText = "allows editing the ledger"))],
      roles = [
        (title = (defaultText = "editor"), permissions = [true],
         verbPhrase = (defaultText = "can edit the ledger"), default = true)
      ],
    ),
  ),
);

const logo :Spk.Metadata.Icon = (svg = embed "firefly.svg");

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "8000", "--", "/bin/bash", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "HOME", value = "/var"),
    (key = "SANDSTORM", value = "1"),
    (key = "TMPDIR", value = "/var/tmp")
  ]
);
