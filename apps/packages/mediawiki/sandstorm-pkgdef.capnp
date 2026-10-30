@0xb2b626bd4d31c1ba;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "vhq5azzdxf68v536fh0je6ckz6wp56f82t3swt2ws3x91nwk19ch",
  manifest = (
    appTitle = (defaultText = "MediaWiki"),
    appVersion = 3,
    minUpgradableAppVersion = 1,
    appMarketingVersion = (defaultText = embed "version.txt"),
    actions = [
      (title = (defaultText = "New MediaWiki"), nounPhrase = (defaultText = "wiki"), command = .myCommand)
    ],
    continueCommand = .myCommand,
    metadata = (
      icons = (
        appGrid = .mediawikiLogo,
        grain = .mediawikiLogo,
        market = .mediawikiLogo,
        marketBig = .mediawikiLogo,
      ),
      website = "https://www.mediawiki.org",
      codeUrl = "https://github.com/zenhack/mediawiki-sandstorm",
      license = (openSource = gpl2),
      categories = [productivity],
      author = (upstreamAuthor = "MediaWiki Contributors"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Wiki"),
      changeLog = (defaultText = embed "changelog.md"),
    ),
  ),
  sourceMap = (
    searchPath = [(sourcePath = "rootfs")]
  ),
  fileList = "sandstorm-files.list",
  alwaysInclude = ["opt/app", "usr", "etc", "sandstorm-http-bridge"],
  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [
        (name = "sysop", title = (defaultText = "sysop"),
         description = (defaultText = "grants MediaWiki administrator permissions"))
      ],
      roles = [
        (title = (defaultText = "admin"), permissions = [true],
         verbPhrase = (defaultText = "can administer wiki")),
        (title = (defaultText = "editor"), permissions = [false],
         verbPhrase = (defaultText = "can view or edit any article"), default = true)
      ],
    ),
    saveIdentityCaps = false,
  ),
);

const mediawikiLogo :Spk.Metadata.Icon = (svg = embed "mediawiki.svg");

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "8000", "--", "/bin/bash", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "HOME", value = "/var"),
    (key = "SANDSTORM", value = "1"),
    (key = "TMPDIR", value = "/var/tmp")
  ]
);
