@0xfd1157d4c17a0001;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "3g05nj7mpryyd3a0erndy30my7fsr72s3xghnhewkqw7km08g34h",
  manifest = (
    appTitle = (defaultText = "Forgejo"),
    appVersion = 1,
    minUpgradableAppVersion = 1,
    appMarketingVersion = (defaultText = "17.0.1"),
    actions = [
      ( title = (defaultText = "New Forgejo instance"),
        nounPhrase = (defaultText = "forge"),
        command = .myCommand )
    ],
    continueCommand = .myCommand,
    metadata = (
      icons = (
        appGrid = (svg = embed "logo.svg"),
        grain = (svg = embed "logo.svg"),
        market = (svg = embed "logo.svg"),
        marketBig = (svg = embed "logo.svg"),
      ),
      website = "https://forgejo.org/",
      codeUrl = "https://codeberg.org/forgejo/forgejo",
      license = (openSource = mit),
      categories = [developerTools],
      author = (upstreamAuthor = "Forgejo contributors"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Federated Git forge and API"),
      changeLog = (defaultText = embed "changelog.md"),
    ),
  ),
  sourceMap = (
    searchPath = [
      ( sourcePath = "rootfs", hidePaths = [ "dev", "proc", "tmp", "var" ] )
    ]
  ),
  fileList = "sandstorm-files.list",
  alwaysInclude = [
    "bin", "etc/ssl/certs", "opt/app", "sandstorm-http-bridge",
    "usr/bin", "usr/lib/git-core", "usr/share/git-core"
  ],
  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [
        (name = "modify", title = (defaultText = "modify"),
         description = (defaultText = "allows creating and modifying repositories and issues"))
      ],
      roles = [
        (title = (defaultText = "editor"), permissions = [true],
         verbPhrase = (defaultText = "can edit"), default = true)
      ],
    ),
    saveIdentityCaps = false,
  )
);

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "8000", "--", "/bin/bash", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/usr/bin:/bin:/usr/lib/git-core"),
    (key = "SANDSTORM", value = "1"),
  ]
);
