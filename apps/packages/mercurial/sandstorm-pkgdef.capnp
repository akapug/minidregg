@0xc3a9f0e2d1b47a68;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "1mvdqjv5z596dtyg5fh0p9573x32u5anrfze9rs6wpxthhyejk50",

  manifest = (
    appTitle = (defaultText = "Mercurial"),
    appVersion = 2,
    minUpgradableAppVersion = 1,
    appMarketingVersion = (defaultText = "7.2.4-2"),

    actions = [
      ( title = (defaultText = "New Mercurial repository"),
        nounPhrase = (defaultText = "repository"),
        command = .myCommand )
    ],
    continueCommand = .myCommand,

    metadata = (
      icons = (
        appGrid = (svg = embed "branding/mercurial.svg"),
        grain = (svg = embed "branding/mercurial.svg"),
        market = (svg = embed "branding/mercurial.svg"),
        marketBig = (svg = embed "branding/mercurial.svg"),
      ),
      website = "https://www.mercurial-scm.org/",
      codeUrl = "https://www.mercurial-scm.org/repo/hg",
      license = (openSource = gpl2),
      categories = [developerTools],
      author = (upstreamAuthor = "Mercurial project"),
      description = (defaultText = embed "branding/description.md"),
      shortDescription = (defaultText = "Distributed source control with hgweb"),
      changeLog = (defaultText = embed "CHANGELOG.md"),
    ),
  ),

  sourceMap = (
    searchPath = [ ( sourcePath = "pkg" ) ]
  ),

  alwaysInclude = [
    "opt/python",
    "opt/app",
    "lib",
    "lib64",
    "etc",
    "sandstorm-http-bridge",
    "sandstorm-manifest",
    "sandstorm-http-bridge-config",
  ],

  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [
        (name = "push", title = (defaultText = "push"),
         description = (defaultText = "allows pushing commits to the repositories"))
      ],
      roles = [
        (title = (defaultText = "contributor"), permissions = [true],
         verbPhrase = (defaultText = "can push"), default = true),
        (title = (defaultText = "viewer"), permissions = [false],
         verbPhrase = (defaultText = "can view"))
      ],
    ),
    saveIdentityCaps = false,
  )
);

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "8000", "--", "/opt/python/bin/python3", "/opt/app/runner.py"],
  environ = [
    (key = "PATH", value = "/opt/python/bin:/usr/local/bin:/usr/bin:/bin"),
    (key = "HOME", value = "/var"),
    (key = "SANDSTORM", value = "1"),
    (key = "PYTHONUNBUFFERED", value = "1"),
  ]
);
