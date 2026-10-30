"""Apply the small, checked Sandstorm adaptations to a MediaWiki release tree."""

from pathlib import Path
import shutil
import sys

root = Path(sys.argv[1])
defines = (root / "includes/Defines.php").read_text()
assert "define( 'MW_VERSION', '1.46.2' );" in defines

images = root / "images"
original = root / "images.orig"
assert images.is_dir() and not images.is_symlink() and not original.exists()
images.rename(original)
images.symlink_to("/var/mediawiki-images")

(root / ".user.ini").write_text(
    "max_execution_time=1800\n"
    "post_max_size=1000M\n"
    "upload_max_filesize=1000M\n"
    "max_input_time=1800\n"
    "max_file_uploads=300\n"
)

startup = root / "resources/src/startup/startup.js"
text = startup.read_text()
marker = "window.parent.postMessage({\n  setPath: location.pathname + location.search,\n}, '*');"
assert marker not in text
startup.write_text(
    text.rstrip()
    + "\n\n// SANDSTORM: update the URL bar outside the iframe.\n"
    + marker
    + "\n"
)

assert (root / "vendor/autoload.php").is_file()
assert (root / "api.php").is_file()
assert (root / "maintenance/install.php").is_file()

# The full release bundles optional extensions which this adapter does not load.
# Keep exactly the old adapter's active upstream extensions; SandstormAuth is
# copied in after this adaptation. Upstream tests are not runtime payload.
extensions = root / "extensions"
keep = {"CodeEditor", "WikiEditor", "ParserFunctions"}
for name in keep:
    assert (extensions / name).is_dir(), name
for extension in extensions.iterdir():
    if extension.is_dir() and extension.name not in keep:
        shutil.rmtree(extension)
shutil.rmtree(root / "tests")

print("MediaWiki 1.46.2 Sandstorm adaptations applied")
