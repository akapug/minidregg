@0xd7e41c6b46a1ef9c;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "j4jvn386t7un76qu6yyw1vwc5ke50t07e38r82kzy4qqg6qq7msh",

  manifest = (
    appTitle = (defaultText = "WBO"),
    appVersion = 21826,
    appMarketingVersion = (defaultText = "2.18.26"),

    actions = [
      ( title = (defaultText = "New WBO Whiteboard"),
        nounPhrase = (defaultText = "whiteboard"),
        command = .myCommand
      )
    ],
    continueCommand = .myCommand,

    metadata = (
      icons = (
        appGrid = (svg = embed "../package-content/whitebophir/client-data/favicon.svg"),
        grain = (svg = embed "../package-content/whitebophir/client-data/favicon.svg"),
        market = (svg = embed "../package-content/whitebophir/client-data/favicon.svg"),
        marketBig = (svg = embed "../package-content/whitebophir/client-data/favicon.svg")
      ),
      website = "https://wbo.ophir.dev",
      codeUrl = "https://github.com/lovasoa/whitebophir",
      license = (openSource = agpl3),
      categories = [graphics],
      author = (upstreamAuthor = "Ophir Lojkine"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Collaborative whiteboard"),
      changeLog = (defaultText = embed "changelog.md")
    )
  ),

  sourceMap = (
    searchPath = [
      (sourcePath = "../package-content/whitebophir", packagePath = "opt/app/whitebophir"),
      (sourcePath = "../runtime/node", packagePath = "opt/app/node"),
      (sourcePath = "../runtime/loader", packagePath = "lib64"),
      (sourcePath = ".", packagePath = "opt/app")
    ]
  ),
  fileList = "sandstorm-files.list",
  alwaysInclude = ["opt/app/whitebophir", "opt/app/node"],

  bridgeConfig = (
    apiPath = "/"
  )
);

const myCommand :Spk.Manifest.Command = (
  argv = [
    "/sandstorm-http-bridge",
    "8000",
    "--",
    "/opt/app/node/bin/node",
    "/opt/app/bootstrap.mjs"
  ],
  environ = [
    (key = "PATH", value = "/opt/app/node/bin:/usr/local/bin:/usr/bin:/bin"),
    (key = "HOME", value = "/var/home"),
    (key = "NODE_ENV", value = "production"),
    (key = "LD_LIBRARY_PATH", value = "/opt/app/node/lib"),
    (key = "PORT", value = "8000"),
    (key = "HOST", value = "127.0.0.1"),
    (key = "WBO_HISTORY_DIR", value = "/var/wbo_data"),
    (key = "WBO_DEFAULT_BOARD", value = "board"),
    (key = "SANDSTORM", value = "1")
  ]
);
