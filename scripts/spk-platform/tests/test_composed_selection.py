"""composed-inputs.sh's selection and resident binding against their consumers' field sets.

The producer is the jq program composed-inputs.sh runs (composed-selection.jq,
composed-resident.jq), invoked with the argument names the script passes; the
consumers are same-store-inputs.py selection_shape / connector allocation,
app-document-provision.py and app-document-journey.py name rules,
connector-authority.py's reader rule and same-world-resident.py's binding fields.
"""
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import unittest

HERE = Path(__file__).resolve().parents[1]
ROOT = HERE.parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    value = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(value)
    return value


inputs = module("same_store_inputs", HERE / "same-store-inputs.py")
resident = module("same_world_resident", ROOT / "testing/journeys/same-world-resident.py")
SCRIPT = (HERE / "composed-inputs.sh").read_text()


def script_args(program):
    """The --arg/--argjson names composed-inputs.sh passes to `jq -n -f "$here/PROGRAM"`."""
    match = re.search(r'jq -n -f "\$here/' + re.escape(program) + r'"((?:[^\n]*\\\n)*[^\n]*)', SCRIPT)
    assert match, program + " is not invoked by composed-inputs.sh"
    return set(re.findall(r"--arg(?:json)? (\w+)", match.group(1)))


def program_vars(program):
    text = "\n".join(line.split("#", 1)[0] for line in (HERE / program).read_text().splitlines())
    bound = set(re.findall(r"as \$(\w+)", text))
    return set(re.findall(r"\$(\w+)", text)) - bound


def run(program, args):
    argv = ["jq", "-n", "-f", str(HERE / program)]
    for name, value in args.items():
        argv += (["--argjson", name, json.dumps(value)] if not isinstance(value, str) else ["--arg", name, value])
    return json.loads(subprocess.run(argv, capture_output=True, check=True).stdout)


SELECTION = {"evidence": "/w/inputs/evidence", "grains": "/var/lib/mini-spk-worlds/0123456789abcdef", "broker": "/x/broker.sock",
             "spk": "/cache/ethercalc.spk", "sha": "93bd2c296692368252ea7b5610a7930db60e5b283340a60b6be8a812c7e309ee",
             "owner": "member-1", "member": "member-2", "op": "jd3"}
CONNECTOR = {"subject": "member-3", "host": "connector.grains.test:8443", "ca": "/w/front/ca.pem"}


class ComposedSelection(unittest.TestCase):
    def test_script_passes_every_argument_each_program_reads(self):
        for program in ("composed-selection.jq", "composed-resident.jq"):
            self.assertEqual(script_args(program), program_vars(program), program)

    def test_without_connector_the_selection_is_exact_and_omits_it(self):
        value = run("composed-selection.jq", {**SELECTION, "connector": None})
        self.assertNotIn("connector", inputs.selection_shape(value))

    def test_connector_selection_satisfies_every_consumer(self):
        value = inputs.selection_shape(run("composed-selection.jq", {**SELECTION, "connector": CONNECTOR}))
        app, c = value["app"], value["connector"]
        self.assertEqual(set(c), set(inputs.CONNECTOR_FIELDS[0]))
        # same-store-inputs.py connector / journey
        self.assertNotIn(c["subject"], [app["owner"], *[row["subject"] for row in app["members"].values()]])
        self.assertRegex(c["name"], r"\A[a-z][a-z0-9-]{0,31}\Z")
        self.assertTrue(inputs.decimal(c["role"]))
        self.assertRegex(c["endpoint"], r"\Ahttps://[a-z0-9.-]+(:[1-9][0-9]{0,4})?/\Z")
        self.assertEqual(c["endpoint"], "https://" + c["expectedHost"] + "/")
        self.assertEqual(c["ca"], CONNECTOR["ca"])
        self.assertNotEqual(c["reader"]["subject"], c["subject"])
        # connector-authority.py: the reader is the app owner; task/document are simple names
        self.assertEqual(c["reader"]["subject"], app["owner"])
        self.assertTrue((ROOT / "scripts/spk-platform/connector-authority.py").read_text().count('reader["subject"] == owner'))
        # app-document-provision.py validate
        for name in (c["task"], c["document"]):
            self.assertRegex(name, r"\A[A-Za-z][A-Za-z0-9_-]{0,63}\Z")
        self.assertRegex(c["sheet"], r"\A[A-Za-z0-9_-]{1,128}\Z")
        # app-document-journey.py
        self.assertRegex(c["operation"], r"\A[A-Za-z0-9-]{1,60}\Z")
        self.assertTrue(all(re.fullmatch(r"[A-Za-z0-9-]{1,64}", part) for part in c["reader"]["document"].split("/")))
        self.assertEqual(c["reader"]["document"], app["room"] + "/notes")

    def test_connector_allocation_is_disjoint_from_the_attached_app(self):
        value = run("composed-selection.jq", {**SELECTION, "connector": CONNECTOR})
        app, c = value["app"], value["connector"]
        used = {**inputs.consecutive(app["resources"], inputs.APP_RESOURCES, "r"), **inputs.consecutive(app["capabilities"], inputs.APP_CAPABILITIES, "c")}
        taken = set(used.values())
        for index, _ in enumerate(app["members"]):
            taken |= set(inputs.consecutive(str(int(app["resources"]) + len(inputs.APP_RESOURCES) + index * len(inputs.SESSION_RESOURCES)), inputs.SESSION_RESOURCES, "s").values())
            taken |= set(inputs.consecutive(str(int(app["capabilities"]) + len(inputs.APP_CAPABILITIES) + index * len(inputs.SESSION_CAPABILITIES)), inputs.SESSION_CAPABILITIES, "s").values())
        mine = set(inputs.consecutive(c["resources"], inputs.SESSION_RESOURCES, "cr").values()) | set(inputs.consecutive(c["capabilities"], inputs.SESSION_CAPABILITIES, "cc").values())
        self.assertFalse(taken & mine)
        self.assertEqual(len(mine), len(inputs.SESSION_RESOURCES) + len(inputs.SESSION_CAPABILITIES))
        # The connector takes the very next block of each (nothing skipped, nothing reused).
        self.assertEqual(int(c["resources"]), max(int(x) for x in taken if int(x) < int(app["capabilities"])) + 1)
        self.assertEqual(int(c["capabilities"]), max(int(x) for x in taken) + 1)

    def test_resident_binding_fields_and_shared_document_alias(self):
        selection = run("composed-selection.jq", {**SELECTION, "connector": CONNECTOR})
        workspace = "/w/root/var/lib/mini/sessions/member-1/workspace"
        binding = run("composed-resident.jq", {"inputs": "/w/inputs/platform-inputs.json", "base": "/w/root", "a0": "member-1", "a1": "member-2",
            "witness": "member-3", "ownerWorkspace": workspace, "document": selection["connector"]["document"],
            "registration": "/w/inputs/resident-registration-receipt.json", "op": "jd3", "acp": "/src/acp", "acpsha": "a" * 64,
            "prov": "/src/prov.py", "provsha": "b" * 64})
        self.assertTrue(resident.REQUIRED <= set(binding) <= resident.REQUIRED | resident.OPTIONAL)
        self.assertEqual(binding["authors"][0], selection["app"]["owner"])
        self.assertEqual(binding["room"]["alias"], selection["app"]["room"])
        # connector-authority.py leaves the founder the alias connector-source-<proposal>, proposal = document.
        reference = Path(binding["sharedDocumentReference"])
        alias = reference.name[:-len(".json")]
        self.assertEqual(alias, "connector-source-" + selection["connector"]["document"])
        self.assertEqual(reference.parent, Path(workspace) / "refs")
        self.assertRegex(alias, r"\A[A-Za-z0-9-]{1,64}\Z")


if __name__ == "__main__":
    unittest.main()
