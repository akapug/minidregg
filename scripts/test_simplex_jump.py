"""The source-binding header exception must not hide executable/import edits."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "jump_check", Path(__file__).with_name("check-simplex-jump.py"))
jump = importlib.util.module_from_spec(spec)
spec.loader.exec_module(jump)


class HeaderBinding(unittest.TestCase):
    def setUp(self):
        self.current = jump.SOURCE.read_text()
        marker = "namespace Minidregg.Kernel.GenericSimplex"
        self.legacy = "import Std\n" + self.current[self.current.index(marker):]

    def test_exact_module_port_preserves_whole_kernel(self):
        self.assertEqual(jump.kernel_code(self.current), jump.code(self.legacy))
        self.assertEqual(jump.kernel_code(self.legacy), jump.code(self.legacy))

    def test_different_or_extra_imports_are_not_erased(self):
        for changed in (
            self.current.replace("public import Std", "public import Lean", 1),
            self.current.replace("import all Init.Util", "import all Init.Util\nimport Lean", 1),
            self.current.replace("@[expose] public section", "public section", 1),
        ):
            with self.subTest(header=jump.code(changed).split("namespace", 1)[0]):
                self.assertNotEqual(jump.kernel_code(changed), jump.code(self.legacy))

    def test_missing_or_wrong_jump_remains_visible(self):
        original = "s := enterView c s (preparedAbove s + 1)"
        self.assertEqual(self.current.count(original), 1)
        for replacement in ("s := s", "s := enterView c s (preparedAbove s)"):
            with self.subTest(replacement=replacement):
                changed = self.current.replace(original, replacement)
                self.assertNotEqual(jump.kernel_code(changed), jump.code(self.legacy))


if __name__ == "__main__":
    unittest.main()
