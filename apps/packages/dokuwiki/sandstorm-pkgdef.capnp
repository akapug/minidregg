@0xd9a49ef8d568a7c1;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "f3c9rjszvmqgvnhan8c6m5cpwkqmwu6t6de0qxa8vnx0rqreafqh",
  manifest = (
    appTitle = (defaultText = "DokuWiki"),
    appVersion = 1,
    minUpgradableAppVersion = 1,
    appMarketingVersion = (defaultText = embed "version.txt"),
    actions = [
      (title = (defaultText = "New Wiki"), nounPhrase = (defaultText = "wiki"), command = .myCommand)
    ],
    continueCommand = .myCommand,
    metadata = (
      icons = (
        appGrid = (png = (dpi1x = embed "appGrid.png")),
        grain = (png = (dpi1x = embed "grain.png")),
        market = (png = (dpi1x = embed "market.png")),
      ),
      website = "https://www.dokuwiki.org",
      codeUrl = "https://github.com/johnbintz/dokuwiki-sandstorm",
      license = (openSource = gpl2),
      categories = [webPublishing, productivity],
      author = (upstreamAuthor = "DokuWiki Team"),
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
        (name = "admin", title = (defaultText = "admin"),
         description = (defaultText = "grants ability to administer wiki")),
        (name = "manager", title = (defaultText = "manager"),
         description = (defaultText = "grants ability to manage wiki")),
        (name = "user", title = (defaultText = "user"),
         description = (defaultText = "grants ability to edit wiki")),
      ],
      roles = [
        (title = (defaultText = "administrator"), permissions = [true, true, true],
         verbPhrase = (defaultText = "can administer the wiki")),
        (title = (defaultText = "manager"), permissions = [false, true, true],
         verbPhrase = (defaultText = "can manage the wiki")),
        (title = (defaultText = "user"), permissions = [false, false, true],
         verbPhrase = (defaultText = "can edit the wiki"), default = true),
        (title = (defaultText = "viewer"), permissions = [false, false, false],
         verbPhrase = (defaultText = "can view the wiki")),
      ],
    ),
    saveIdentityCaps = false,
  ),
);

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "8000", "--", "/bin/bash", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "HOME", value = "/var"),
    (key = "SANDSTORM", value = "1"),
    (key = "TMPDIR", value = "/var/tmp")
  ]
);
