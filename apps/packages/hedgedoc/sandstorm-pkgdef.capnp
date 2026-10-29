@0x8169ddc3367aecb9;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "a0wt1wk03g737k60grvphm2rxy9yjnkev8g4jjj9zgu9mm3ggay0",

  manifest = (
    appTitle = (defaultText = "HedgeDoc"),
    appVersion = 9,
    appMarketingVersion = (defaultText = "1.12.0"),

    actions = [
      ( nounPhrase = (defaultText = "note"), command = .myCommand )
    ],
    continueCommand = .myCommand,

    metadata = (
      icons = (
        appGrid = (png = (dpi1x = embed "../build/source/public/icons/android-chrome-192x192.png")),
        grain = (png = (dpi1x = embed "../build/source/public/icons/favicon-32x32.png")),
        market = (png = (dpi1x = embed "../build/source/public/icons/android-chrome-192x192.png")),
        marketBig = (png = (dpi1x = embed "../build/source/public/icons/android-chrome-512x512.png"))
      ),
      website = "https://hedgedoc.org",
      codeUrl = "https://github.com/hedgedoc/hedgedoc",
      license = (openSource = agpl3),
      categories = [office],
      author = (upstreamAuthor = "HedgeDoc App Team"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Markdown editor"),
      screenshots = [
        (width = 1280, height = 720, png = embed "../build/source/public/screenshot.png")
      ],
      changeLog = (defaultText = embed "changelog.md")
    )
  ),

  sourceMap = (
    searchPath = [
      (sourcePath = "../build/source", packagePath = "opt/app/hedgedoc"),
      (sourcePath = "../runtime/node", packagePath = "opt/app/node"),
      (sourcePath = "../runtime/loader", packagePath = "lib64"),
      (sourcePath = ".", packagePath = "opt/app")
    ]
  ),

  fileList = "sandstorm-files.list",
  alwaysInclude = [
    "opt/app/hedgedoc",
    "opt/app/node"
  ],

  bridgeConfig = (
    apiPath = "/"
  )
);

const myCommand :Spk.Manifest.Command = (
  argv = [
    "/sandstorm-http-bridge",
    "3000",
    "--",
    "/opt/app/node/bin/node",
    "/opt/app/bootstrap.js"
  ],
  environ = [
    (key = "PATH", value = "/opt/app/node/bin:/usr/local/bin:/usr/bin:/bin"),
    (key = "HOME", value = "/opt/app"),
    (key = "NODE_ENV", value = "production"),
    (key = "LD_LIBRARY_PATH", value = "/opt/app/node/lib"),
    (key = "SANDSTORM", value = "1")
  ]
);
