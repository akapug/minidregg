#!/usr/bin/env python3
"""render-enrol, run for real (no Lean, no Rust, no network). usage: python3 deploy/pay/test-render-enrol.py

Pins the operator ruling (50 DREGG per week) to the integers the tariff carries, and the receiving
address to the deployment's own key (--enrol-address-file), never a literal in the repo: the tariff's unit is the week, so the week is exactly 50.000000 DREGG (cv 01a105c0-0292: the
hourly unit made it 49.999992). A tariff at 49.999992, or one still carrying an hourly rate, is refused.
Every refusal is by name.
"""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True

HERE = Path(__file__).resolve().parent
RENDER = HERE / "render-enrol"
TERMS = HERE / "enrol-terms.json"
ADDRESS = "5N2uUG4TEwvM4acjWRpZ981CJa4p5e9RcuAYQvuUZLp6"
sys.path.insert(0, str(HERE))
from importlib.machinery import SourceFileLoader  # noqa: E402
render_module = SourceFileLoader("render_enrol", str(RENDER)).load_module()


ADDRESS_FILE = Path(tempfile.mkdtemp(prefix="render-enrol-key-")) / "enrol.pub"
ADDRESS_FILE.write_bytes(render_module.b58_decode32(ADDRESS, "test address"))


def run(out, terms=TERMS, version="1", extra=(), network=("--network", "mainnet"), address=ADDRESS_FILE):
    head = [sys.executable, str(RENDER), "--terms", str(terms), "--out", str(out), "--version", version,
            "--control", "53", "--observer-capability", "4030", "--enrol-capability", "4032", *network]
    if address is not None:
        head += ["--enrol-address-file", str(address)]
    return subprocess.run([*head, *extra], capture_output=True, text=True)


class Rendered(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.tmp = tempfile.TemporaryDirectory(prefix="render-enrol-")
        cls.out = Path(cls.tmp.name) / "out"
        done = run(cls.out)
        assert done.returncode == 0, done.stderr
        cls.book = json.loads((cls.out / "book.json").read_text())
        cls.on = json.loads((cls.out / "tariff-on.json").read_text())

    @classmethod
    def tearDownClass(cls):
        cls.tmp.cleanup()

    def test_week_rate_is_exactly_fifty_tokens_a_week(self):
        tariff = self.book["tariff"]
        self.assertNotIn("nodeHourRate", tariff)
        self.assertEqual(tariff["nodeWeekRate"], "50000000")  # Kernel.PayTariff.Tariff.nodeWeekRate, exact
        self.assertEqual(tariff["creditPerAtomic"], "1")
        self.assertEqual(tariff["decimals"], "6")
        self.assertEqual(int(tariff["nodeWeekRate"]), 50 * 10 ** int(tariff["decimals"]))

    def test_a_payer_of_exactly_the_asked_amount_is_exactly_at_the_price(self):
        week_credit = int(self.book["tariff"]["nodeWeekRate"])
        for birth_fee in (0, 7, 9, 1000):  # Kernel.PayEnrolDecision.enrolPrice = birthFee + nodeWeekRate
            self.assertEqual(50 * 10 ** 6 + birth_fee, birth_fee + week_credit)
        # one atomic unit less is below the price: no payer is quietly priced in at 49.999992
        self.assertLess(49_999_992, week_credit)
        # a renewal of exactly 50 tokens buys one whole week (RenewPlan.weeks = credit / nodeWeekRate)
        self.assertEqual(50 * 10 ** 6 // week_credit, 1)
        self.assertEqual((50 * 10 ** 6 - 8) // week_credit, 0)

    def test_the_report_states_the_exact_week(self):
        report = (self.out / "report.txt").read_text()
        self.assertIn("nodeWeekRate        50000000", report)
        self.assertNotIn("49999992", report)
        self.assertNotIn("floor", report)

    def test_the_address_is_book_row_zero_and_the_pins_name_it(self):
        self.assertEqual(self.book["book"][0], ADDRESS)
        self.assertIsNone(self.book["tariff"]["enrolIndex"])
        self.assertEqual(self.on["book"], [])
        self.assertEqual(self.on["tariff"]["enrolIndex"], "0")
        self.assertEqual(self.on["tariff"]["version"], "2")
        v1 = json.loads((self.out / "enrol.json").read_text())
        v2 = json.loads((self.out / "enrol-v2.json").read_text())
        self.assertEqual((v1["type"], v1["enrolAddress"]), ("minidregg-enrol-pin-v1", ADDRESS))
        self.assertEqual((v2["type"], v2["enrolAddress"], v2["decimals"]), ("minidregg-enrol-pin-v2", ADDRESS, "6"))
        self.assertEqual(sorted(v2), sorted(["type", "enrolAddress", "mint", "tokenProgram", "decimals", "login"]))
        self.assertEqual(len(render_module.b58_decode32(ADDRESS, "address")), 32)

    def test_the_tick_env_carries_the_enrollment_quartet_and_no_address_or_rate(self):
        env = (self.out / "watcher.env").read_text()
        lines = dict(l.split("=", 1) for l in env.splitlines() if l and not l.startswith("#"))
        self.assertEqual(lines["PAY_WATCH_ENROL"], "yes")
        self.assertNotIn("PAY_ENROL_INDEX", lines)
        self.assertNotIn("PAY_JOURNAL_FLOOR", lines)
        self.assertEqual(lines["PAY_ENROL_CAPABILITY"], "4032")
        self.assertEqual(lines["PAY_OPERATOR_SOCKET"], "/var/lib/mini/store/node/operator/mini.sock")
        self.assertNotIn(ADDRESS, env)
        self.assertNotIn("50000000", env)

    def test_base58_round_trip_and_one_source(self):
        for raw in (bytes(range(1, 33)), b"\0" + bytes(range(1, 32))):
            self.assertEqual(render_module.b58_decode32(render_module.b58_encode(raw), "k"), raw)
        # the rate is stated in the terms file and prose docs only; no address is stated anywhere in deploy/
        repo = HERE.parents[1]
        for path in [p for p in (repo / "deploy").rglob("*") if p.is_file() and p.suffix in {".sh", ".json", ".py", ".service", ".timer", ".env", ""}]:
            if path.name in {"test-render-enrol.py"}:
                continue
            try:
                text = path.read_text()
            except UnicodeDecodeError:
                continue
            self.assertNotIn(ADDRESS, text, str(path))
            self.assertNotIn("297619", text, str(path))  # the retired hourly integer
            self.assertNotIn("49999992", text, str(path))


class Refusals(unittest.TestCase):
    def refuse(self, mutate, want, extra=()):
        terms = json.loads(TERMS.read_text())
        mutate(terms)
        with tempfile.TemporaryDirectory(prefix="render-enrol-r-") as tmp:
            path = Path(tmp) / "terms.json"
            path.write_text(json.dumps(terms))
            done = run(Path(tmp) / "out", terms=path, extra=extra)
            self.assertNotEqual(done.returncode, 0, "accepted")
            self.assertIn(want, done.stderr)
            self.assertFalse((Path(tmp) / "out").exists(), "left an output directory behind")

    def test_refusals(self):
        self.refuse(lambda t: t.update(enrolAddress=ADDRESS), "fields differ")  # an address in the terms
        self.refuse(lambda t: t.update(weekPriceAtomic="0"), "must be positive")
        self.refuse(lambda t: t.update(weekPriceAtomic="05000000"), "canonical decimal")
        self.refuse(lambda t: t.update(journalFloor="60000000"), "journalFloor above the week price")
        self.refuse(lambda t: t.update(decimals="39"), "decimals exceed")
        self.refuse(lambda t: t.update(extra="x"), "fields differ")
        self.refuse(lambda t: t.update(operatorSocket="mini.sock"), "absolute path")
        self.refuse(lambda t: t.update(enrolIndex="1"), "enrolIndex must be 0")

    def test_the_address_comes_from_the_deployment_key_and_devnet_needs_its_mint(self):
        with tempfile.TemporaryDirectory(prefix="render-enrol-n-") as tmp:
            done = run(Path(tmp) / "a", address=None)
            self.assertIn("--enrol-address-file", done.stderr)
            short = Path(tmp) / "short.pub"
            short.write_bytes(b"\1" * 31)
            self.assertIn("32-byte", run(Path(tmp) / "b", address=short).stderr)
            zero = Path(tmp) / "zero.pub"
            zero.write_bytes(b"\0" * 32)
            self.assertIn("non-zero", run(Path(tmp) / "c", address=zero).stderr)
            done = run(Path(tmp) / "d", network=("--network", "devnet"))
            self.assertIn("devnet has no DREGG mint", done.stderr)
            self.assertFalse((Path(tmp) / "d").exists())
            devmint = render_module.b58_encode(bytes(range(1, 33)))
            program = render_module.b58_encode(bytes(range(2, 34)))
            done = run(Path(tmp) / "e", network=("--network", "devnet"), extra=("--mint", devmint, "--token-program", program))
            self.assertEqual(done.returncode, 0, done.stderr)
            pin = json.loads((Path(tmp) / "e" / "enrol-v2.json").read_text())
            self.assertEqual((pin["enrolAddress"], pin["mint"]), (ADDRESS, devmint))
            self.assertIn("network             devnet", (Path(tmp) / "e" / "report.txt").read_text())

    def test_existing_output_and_duplicate_rows_are_refused(self):
        with tempfile.TemporaryDirectory(prefix="render-enrol-e-") as tmp:
            existing = Path(tmp) / "out"
            existing.mkdir()
            done = run(existing)
            self.assertNotEqual(done.returncode, 0)
            self.assertIn("refusing existing output", done.stderr)
            extras = Path(tmp) / "extra"
            extras.write_text(ADDRESS + "\n")
            done = run(Path(tmp) / "out2", extra=("--book-extra", str(extras)))
            self.assertNotEqual(done.returncode, 0)
            self.assertIn("repeats an address", done.stderr)


class VerifyTariff(unittest.TestCase):
    """`render-enrol --verify-tariff`: the planted 49.999992 tariffs of the retired hourly unit are refused."""

    def verify(self, tariff, extra=()):
        with tempfile.TemporaryDirectory(prefix="render-enrol-v-") as tmp:
            path = Path(tmp) / "tariff.json"
            path.write_text(json.dumps(tariff))
            return subprocess.run([sys.executable, str(RENDER), "--terms", str(TERMS), "--verify-tariff", str(path), *extra],
                                  capture_output=True, text=True)

    def rendered(self):
        with tempfile.TemporaryDirectory(prefix="render-enrol-g-") as tmp:
            done = run(Path(tmp) / "out")
            assert done.returncode == 0, done.stderr
            return json.loads((Path(tmp) / "out" / "book.json").read_text())

    def test_the_rendered_tariff_verifies(self):
        book = self.rendered()
        done = self.verify(book)
        self.assertEqual(done.returncode, 0, done.stderr)
        self.assertIn("50 tokens exactly", done.stdout)
        self.assertEqual(self.verify(book["tariff"]).returncode, 0)

    def test_planted_49_999_992_week_is_refused(self):
        tariff = self.rendered()["tariff"]
        tariff["nodeWeekRate"] = "49999992"
        done = self.verify(tariff)
        self.assertNotEqual(done.returncode, 0, "accepted a 49.999992 week")
        self.assertIn("week rate is '49999992' credit, the terms ask exactly 50000000", done.stderr)

    def test_the_retired_hourly_tariff_is_refused(self):
        tariff = self.rendered()["tariff"]
        del tariff["nodeWeekRate"]
        tariff["nodeHourRate"] = "297619"  # 168 * 297619 = 49_999_992: the retired derivation
        done = self.verify(tariff)
        self.assertNotEqual(done.returncode, 0, "accepted an hourly tariff")
        self.assertIn("carries an hourly rate", done.stderr)

    def test_a_wrong_mint_or_scale_is_refused(self):
        tariff = self.rendered()["tariff"]
        for name, value in (("mint", ADDRESS), ("creditPerAtomic", "2"), ("decimals", "9")):
            planted = dict(tariff, **{name: value})
            done = self.verify(planted)
            self.assertNotEqual(done.returncode, 0, name)
            self.assertIn(name, done.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
