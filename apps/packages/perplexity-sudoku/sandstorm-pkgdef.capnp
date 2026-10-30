@0xd1a0f1c2b3a49586;

using Spk = import "/sandstorm/package.capnp";

const pkgdef :Spk.PackageDefinition = (
  id = "1xs63fcv99c08dv2tgv0dcehjka9141e1egcafffuu0txskvzmq0",
  manifest = (
    appTitle = (defaultText = "Perplexity Sudoku"),
    appVersion = 2,
    appMarketingVersion = (defaultText = embed "version.txt"),
    actions = [
      (title = (defaultText = "New Sudoku"), nounPhrase = (defaultText = "instance"), command = .myCommand)
    ],
    continueCommand = .myCommand,
    metadata = (
      icons = (
        appGrid = .logo, grain = .logo, market = .logo, marketBig = .logo,
      ),
      website = "https://github.com/ocdtrekkie/perplexity-sudoku",
      codeUrl = "https://github.com/ocdtrekkie/perplexity-sudoku",
      license = (openSource = mit),
      categories = [games],
      author = (upstreamAuthor = "Jacob Weisz"),
      description = (defaultText = embed "description.md"),
      shortDescription = (defaultText = "Number puzzle"),
      changeLog = (defaultText = embed "changelog.md"),
    ),
  ),
  sourceMap = (searchPath = [(sourcePath = "rootfs")]),
  fileList = "sandstorm-files.list",
  alwaysInclude = ["opt/app", "usr", "etc", "bin", "lib", "lib64", "sandstorm-http-bridge"],
  bridgeConfig = (
    apiPath = "/",
    viewInfo = (
      permissions = [(name = "admin", title = (defaultText = "admin"),
                      description = (defaultText = "allows full access to game data"))],
    ),
  ),
);

const logo :Spk.Metadata.Icon = (svg = embed "sudoku.svg");

const myCommand :Spk.Manifest.Command = (
  argv = ["/sandstorm-http-bridge", "5000", "--", "/bin/bash", "/opt/app/launcher.sh"],
  environ = [
    (key = "PATH", value = "/usr/local/bin:/usr/bin:/bin"),
    (key = "SANDSTORM", value = "1"),
  ]
);
