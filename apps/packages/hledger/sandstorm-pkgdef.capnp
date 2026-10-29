@0xbc169f81a53d625c;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "894fztp7d6e4u8fgw2qtm8jv904jw6w19frfqgc0pwytj0q10s80",

  manifest = (
    appTitle = (defaultText = "Hledger Web"),
    appVersion = 15204,
    appMarketingVersion = (defaultText = "1.52.4"),

    actions = [
      ( title = (defaultText = "New Ledger"),
        nounPhrase = (defaultText = "ledger"),
        command = .myCommand )
    ],
    continueCommand = .myCommand,

    metadata = (
      icons = (
        appGrid = (svg = embed "appGrid.svg"),
        grain = (svg = embed "grain.svg"),
        market = (svg = embed "market.svg")
      ),
      website = "https://hledger.org",
      codeUrl = "https://github.com/hledgerorg/hledger",
      license = (openSource = gpl3),
      categories = [office, productivity],
      author = (upstreamAuthor = "Hledger Team"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Plain-text accounting"),
      screenshots = [
        (width = 1920, height = 1040, png = embed "screenshot1.png"),
        (width = 1920, height = 1040, png = embed "screenshot2.png"),
        (width = 1920, height = 1040, png = embed "screenshot3.png")
      ],
      changeLog = (defaultText = embed "changelog.md")
    )
  ),

  sourceMap = (
    searchPath = [(sourcePath = ".")]
  ),
  fileList = "sandstorm-files.list",
  alwaysInclude = [],

  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [
        (name = "view", title = (defaultText = "view"),
         description = (defaultText = "allows viewing the journal and reports")),
        (name = "add", title = (defaultText = "add"),
         description = (defaultText = "allows adding transactions")),
        (name = "edit", title = (defaultText = "edit"),
         description = (defaultText = "allows editing and uploading the journal"))
      ],
      roles = [
        (title = (defaultText = "editor"), permissions = [true, true, true],
         verbPhrase = (defaultText = "can edit"), default = true),
        (title = (defaultText = "adder"), permissions = [true, true, false],
         verbPhrase = (defaultText = "can add transactions")),
        (title = (defaultText = "viewer"), permissions = [true, false, false],
         verbPhrase = (defaultText = "can view"))
      ]
    )
  )
);

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "8000", "--", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/opt/app:/usr/local/bin:/usr/bin:/bin"),
    (key = "HOME", value = "/var"),
    (key = "SANDSTORM", value = "1")
  ]
);
