@0xbfac064ab1e37408;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "f3s5vv8g7xuay08e3x1g5zwuaycz0mt7170nmz3kf5e1g1q9ytr0",

  manifest = (
    appTitle = (defaultText = "Datasette"),
    appVersion = 1,
    appMarketingVersion = (defaultText = (embed "version")),

    actions = [
      (nounPhrase = (defaultText = "dataset"), command = .myCommand)
    ],
    continueCommand = .myCommand,

    metadata = (
      icons = (
        appGrid = (svg = embed "datasette.svg"),
        grain = (svg = embed "datasette.svg"),
        market = (svg = embed "datasette.svg"),
        marketBig = (svg = embed "datasette.svg"),
      ),
      website = "https://datasette.io",
      codeUrl = "https://github.com/ocdtrekkie/datasette-sandstorm",
      license = (openSource = apache2),
      categories = [science],
      author = (upstreamAuthor = "Simon Willison"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Read-only data explorer"),
      changeLog = (defaultText = embed "changelog.md"),
    ),
  ),

  sourceMap = (
    searchPath = [
      (sourcePath = "rootfs")
    ]
  ),

  fileList = "sandstorm-files.list",
  alwaysInclude = ["opt/app", "usr", "lib", "lib64", "etc"],

  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [
        (
          name = "admin",
          title = (defaultText = "admin"),
          description = (defaultText = "grants access to Datasette debug information"),
        ),
        (
          name = "edit",
          title = (defaultText = "edit"),
          description = (defaultText = "reserved legacy Sandstorm permission; this package is read-only"),
        ),
      ],
      roles = [
        (
          title = (defaultText = "administrator"),
          permissions = [true, true],
          verbPhrase = (defaultText = "can view data and debug information"),
          description = (defaultText = "administrators can view all grain data and debug information."),
        ),
        (
          title = (defaultText = "editor"),
          permissions = [false, true],
          verbPhrase = (defaultText = "can view data"),
          description = (defaultText = "editors can view data; HTTP writes are not available."),
        ),
        (
          title = (defaultText = "viewer"),
          permissions = [false, false],
          verbPhrase = (defaultText = "can view data"),
          description = (defaultText = "viewers can view data and run read-only SQL queries."),
        ),
      ],
    ),
  ),
);

const myCommand :Spk.Manifest.Command = (
  argv = [
    "/sandstorm-http-bridge",
    "8001",
    "--",
    "/opt/app/venv/bin/python",
    "-I",
    "/opt/app/launcher.py"
  ],
  environ = [
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "SANDSTORM", value = "1"),
    (key = "TMPDIR", value = "/var/tmpfs"),
    (key = "PYTHONDONTWRITEBYTECODE", value = "1"),
    (key = "PYTHONUTF8", value = "1"),
  ]
);
