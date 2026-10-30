@0xe7b3c4d5a6f70819;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "reh7pa3e7jt8ryvjgje97ke5rkyztfg70grru8dewevmunj6ugn0",
  manifest = (
    appTitle = (defaultText = "3D Blockstack"),
    appVersion = 2,
    appMarketingVersion = (defaultText = embed "version.txt"),
    actions = [
      (title = (defaultText = "New 3D Blockstack"), nounPhrase = (defaultText = "game"), command = .myCommand)
    ],
    continueCommand = .myCommand,
    metadata = (
      icons = (
        appGrid = (png = (dpi1x = embed "bigicon.png")),
        grain = (png = (dpi1x = embed "bigicon.png")),
        market = (png = (dpi1x = embed "bigicon.png")),
        marketBig = (png = (dpi1x = embed "bigicon.png")),
      ),
      website = "https://github.com/ocdtrekkie/3D-Blockstack-sandstorm",
      codeUrl = "https://github.com/ocdtrekkie/3D-Blockstack-sandstorm",
      license = (openSource = mit),
      categories = [games],
      author = (upstreamAuthor = "Jacob Weisz"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Stacking game"),
      changeLog = (defaultText = embed "changelog.md"),
    ),
  ),
  sourceMap = (searchPath = [(sourcePath = "rootfs")]),
  fileList = "sandstorm-files.list",
  alwaysInclude = ["opt/app", "usr", "etc", "bin", "lib", "lib64", "sandstorm-http-bridge"],
  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [(name = "play", title = (defaultText = "play"),
                      description = (defaultText = "allows playing and saving scores"))],
    ),
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
