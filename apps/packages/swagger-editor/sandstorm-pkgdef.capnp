@0xe1a5b9d3f7c24680;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "xm16d84ksseg44ef58z7n2aw7qt1n6psk0cewzr0e0arfjk5r4fh",

  manifest = (
    appTitle = (defaultText = "Swagger Editor"),
    appVersion = 2,
    minUpgradableAppVersion = 2,
    appMarketingVersion = (defaultText = "5.10.0-2"),

    actions = [
      ( title = (defaultText = "New API Specification"),
        nounPhrase = (defaultText = "API spec"),
        command = .myCommand )
    ],
    continueCommand = .myCommand,

    metadata = (
      icons = (
        appGrid = (svg = embed "branding/swagger-editor.svg"),
        grain = (svg = embed "branding/swagger-editor.svg"),
        market = (svg = embed "branding/swagger-editor.svg"),
        marketBig = (svg = embed "branding/swagger-editor.svg"),
      ),
      website = "https://editor.swagger.io/",
      codeUrl = "https://github.com/swagger-api/swagger-editor",
      license = (openSource = apache2),
      categories = [developerTools],
      author = (upstreamAuthor = "SmartBear Software and swagger-api contributors"),
      description = (defaultText = embed "branding/description.md"),
      shortDescription = (defaultText = "Design and document APIs in OpenAPI"),
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
         description = (defaultText = "allows editing the specification"))
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
