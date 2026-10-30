@0xe37cee3c3b17db56;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "1124qk4mm5zvx294gwn9w23gn2pt96mds6pqkxpn9sxr8w2uwr70",

  manifest = (
    appTitle = (defaultText = "Scrumblr"),
    appVersion = 1,
    minUpgradableAppVersion = 1,
    appMarketingVersion = (defaultText = "0.5-1"),

    actions = [
      ( title = (defaultText = "New Scrumblr Board"),
        nounPhrase = (defaultText = "board"),
        command = .myCommand )
    ],
    continueCommand = .myCommand,

    metadata = (
      icons = (
        appGrid = (svg = embed "branding/scrumblr.svg"),
        grain = (svg = embed "branding/scrumblr.svg"),
        market = (svg = embed "branding/scrumblr.svg"),
        marketBig = (svg = embed "branding/scrumblr.svg"),
      ),
      website = "https://scrumblr.ca/",
      codeUrl = "https://github.com/aliasaria/scrumblr",
      license = (openSource = gpl3),
      categories = [productivity, office],
      author = (upstreamAuthor = "Ali Asaria"),
      description = (defaultText = embed "branding/description.md"),
      shortDescription = (defaultText = "Collaborative scrum board with sticky notes"),
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
         description = (defaultText = "allows adding, editing and moving cards on the board"))
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
  argv = ["/sandstorm-http-bridge", "8080", "--", "/bin/bash", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/opt/app/node/bin:/opt/app/redis/bin:/usr/local/bin:/usr/bin:/bin"),
    (key = "NODE_ENV", value = "production"),
    (key = "SANDSTORM", value = "1"),
    (key = "REDIS_URL", value = "redis://127.0.0.1:6379"),
  ]
);
