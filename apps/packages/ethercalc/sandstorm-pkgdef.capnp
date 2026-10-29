@0xf743d7c210e66991;

using Spk = import "/sandstorm/package.capnp";

# EtherCalc 0.20261026.0, adapted from the tagged upstream pkgdef for the
# SPK-FRESH app signing identity. Runtime files are enumerated explicitly by
# package.sh because the upstream sandstorm-files.list is only a stub.
const pkgdef :Spk.PackageDefinition = (
  id = "umpy9re0saa7vtckd6mnprv6mc5vjgr0qh5qucs4na3qjrxrrzch",

  manifest = (
    appVersion = 202610260,
    appTitle = (defaultText = "EtherCalc"),
    appMarketingVersion = (defaultText = "2026.10.26.0+sandstorm1"),

    actions = [
      ( title = (defaultText = "New EtherCalc Spreadsheet"),
        nounPhrase = (defaultText = "spreadsheet"),
        command = .myContinueCommand
      )
    ],
    continueCommand = .myContinueCommand,

    metadata = (
      icons = (
        appGrid = (svg = embed "app-graphics/ethercalc-128.svg"),
        grain = (svg = embed "app-graphics/ethercalc-24.svg"),
        market = (svg = embed "app-graphics/ethercalc-150.svg"),
      ),
      website = "https://ethercalc.net/",
      codeUrl = "https://github.com/audreyt/ethercalc",
      license = (openSource = cpal),
      categories = [office, productivity],
      author = (upstreamAuthor = "Audrey Tang"),
      description = (defaultText = embed "DESCRIPTION.mkdn"),
      shortDescription = (defaultText = "Multi-user Spreadsheet"),
      screenshots = [
        (width = 478, height = 298, png = embed "static/img/davy/gfx/screenshot.png")
      ],
      changeLog = (defaultText = embed "CHANGELOG.mkdn"),
    ),
  ),

  sourceMap = (
    searchPath = [
      ( sourcePath = "." ),
      ( sourcePath = "/", hidePaths = [ "home", "proc", "sys" ] )
    ]
  ),
  fileList = "sandstorm-files.list",
  alwaysInclude = [],

  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [(name = "modify", title = (defaultText = "modify"),
                      description = (defaultText = "allows modifying the spreadsheet"))],
      roles = [(title = (defaultText = "editor"),
                permissions = [true],
                verbPhrase = (defaultText = "can edit"),
                default = true),
               (title = (defaultText = "viewer"),
                permissions = [false],
                verbPhrase = (defaultText = "can view"))]
    )
  )
);

const myContinueCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "33411", "--", "./run_grain.sh"],
  environ = [
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "OPENSHIFT_DATA_DIR", value = "/var"),
  ]
);
