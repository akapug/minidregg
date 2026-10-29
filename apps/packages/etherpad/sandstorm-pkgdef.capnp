@0xee9207e3a666d632;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "ksyn7qa4szjwa14v89r7znxwrpjs0dez5q2u8s810d0awnuswmfh",

  manifest = (
    appTitle = (defaultText = "Etherpad"),
    appVersion = 1,
    minUpgradableAppVersion = 1,
    appMarketingVersion = (defaultText = "3.3.12-1"),

    actions = [
      ( title = (defaultText = "New Etherpad Document"),
        nounPhrase = (defaultText = "pad"),
        command = .myCommand )
    ],
    continueCommand = .myCommand,

    metadata = (
      icons = (
        appGrid = (svg = embed "branding/etherpad.svg"),
        grain = (svg = embed "branding/etherpad.svg"),
        market = (svg = embed "branding/etherpad.svg"),
        marketBig = (svg = embed "branding/etherpad.svg"),
      ),
      website = "https://etherpad.org/",
      codeUrl = "https://github.com/ether/etherpad",
      license = (openSource = apache2),
      categories = [office, productivity],
      author = (upstreamAuthor = "Etherpad Foundation"),
      description = (defaultText = embed "branding/description.md"),
      shortDescription = (defaultText = "Collaborative document editor"),
      changeLog = (defaultText = embed "CHANGELOG.md"),
    ),
  ),

  sourceMap = (
    searchPath = [ ( sourcePath = "rootfs" ) ]
  ),

  alwaysInclude = [
    "opt/app",
    "bin",
    "lib",
    "lib64",
    "etc",
    "sandstorm-manifest",
    "sandstorm-http-bridge",
    "sandstorm-http-bridge-config",
  ],

  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [
        (name = "modify", title = (defaultText = "modify"),
         description = (defaultText = "allows modifying the document"))
      ],
      roles = [
        (title = (defaultText = "editor"), permissions = [true],
         verbPhrase = (defaultText = "can edit"), default = true),
        (title = (defaultText = "viewer"), permissions = [false],
         verbPhrase = (defaultText = "can view"))
      ],
    ),
    saveIdentityCaps = false,
  )
);

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "9001", "--", "/bin/bash", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/opt/app/node/bin:/usr/local/bin:/usr/bin:/bin"),
    (key = "NODE_ENV", value = "production"),
    (key = "SANDSTORM", value = "1"),
  ]
);
