import base64
import contextlib
import importlib.util
import io
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch


spec = importlib.util.spec_from_file_location(
    "proton_vpn_profiles", Path(__file__).with_name("proton_vpn_profiles.py")
)
profiles = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = profiles
spec.loader.exec_module(profiles)


PRIVATE_KEY = base64.b64encode(bytes([1]) * 32).decode()
PUBLIC_KEY = base64.b64encode(bytes([2]) * 32).decode()
PRESHARED_KEY = base64.b64encode(bytes([3]) * 32).decode()


def config(endpoint, *, private_key=PRIVATE_KEY, public_key=PUBLIC_KEY, dns=True, extra=""):
    dns_line = "DNS = 10.2.0.1, 2a07:b944::2:1\n" if dns else ""
    return (
        "# profile fixture\n"
        "[Interface]\n"
        f"PrivateKey = {private_key}\n"
        "Address = 10.2.0.2/32, 2a07:b944::2:2/128\n"
        f"{dns_line}"
        "MTU = 1420\n"
        f"{extra}"
        "[Peer]\n"
        f"PublicKey = {public_key}\n"
        f"PresharedKey = {PRESHARED_KEY}\n"
        "AllowedIPs = 0.0.0.0/0, ::/0\n"
        f"Endpoint = {endpoint}\n"
        "PersistentKeepalive = 25\n"
    )


class ProfileStoreTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.store = profiles.ProfileStore(self.root)

    def write(self, relative, text, mode=0o600):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        path.chmod(mode)
        return path

    def test_legacy_primary_is_accepted_without_extra_directory(self):
        primary = self.write("proton0.conf", config("198.51.100.10:51820"))

        loaded = self.store.load()

        self.assertEqual([profile.name for profile in loaded], ["primary"])
        self.assertEqual(loaded[0].source, primary)
        self.assertEqual(loaded[0].endpoint_host, "198.51.100.10")
        self.assertEqual(loaded[0].endpoint_port, 51820)
        self.assertEqual(profiles.read_profile(primary, "download").endpoint_port, 51820)

    def test_switch_keeps_the_complete_selected_profile_and_key(self):
        self.write("proton0.conf", config("198.51.100.10:51820"))
        backup_private = base64.b64encode(bytes([4]) * 32).decode()
        backup_public = base64.b64encode(bytes([5]) * 32).decode()
        backup = config(
            "[2001:db8::42]:51821",
            private_key=backup_private,
            public_key=backup_public,
            extra="ListenPort = 47111\n",
        )
        backup_path = self.write("profiles/jp.conf", backup)
        runtime = self.root / "run" / "proton0.conf"

        candidates = self.store.load()
        selected = self.store.select(candidates[1])
        profiles.prepare(self.store, runtime)

        self.assertEqual(selected.name, "jp")
        self.assertEqual(self.store.selected(candidates).name, "jp")
        self.assertIn(f"PrivateKey = {backup_private}", runtime.read_text())
        self.assertIn(f"PublicKey = {backup_public}", runtime.read_text())
        self.assertIn("ListenPort = 47111", runtime.read_text())
        self.assertNotIn("DNS =", runtime.read_text())
        self.assertEqual(backup_path.read_text(), backup)
        self.assertEqual(stat.S_IMODE(runtime.stat().st_mode), 0o600)
        self.assertEqual(runtime.stat().st_uid, os.geteuid())

    def test_selection_replacement_uses_one_atomic_replace(self):
        self.write("proton0.conf", config("198.51.100.10:51820"))
        self.write("profiles/us.conf", config("198.51.100.11:51820"))
        candidates = self.store.load()

        with patch.object(profiles.os, "replace", wraps=profiles.os.replace) as replace:
            self.store.select(candidates[1])

        replace.assert_called_once()
        self.assertTrue(self.store.active_path.is_symlink())
        self.assertEqual(self.store.selected(candidates).name, "us")
        self.assertEqual(list(self.root.glob(".active.*")), [])

    def test_failed_selection_preserves_previous_selector(self):
        self.write("proton0.conf", config("198.51.100.10:51820"))
        self.write("profiles/us.conf", config("198.51.100.11:51820"))
        candidates = self.store.load()
        self.store.select(candidates[0])

        with patch.object(profiles.os, "replace", side_effect=OSError("replace failed")):
            with self.assertRaises(OSError):
                self.store.select(candidates[1])

        self.assertEqual(self.store.selected(candidates).name, "primary")
        self.assertEqual(list(self.root.glob(".active.*")), [])

    def test_runtime_write_failure_keeps_previous_file(self):
        self.write("proton0.conf", config("198.51.100.10:51820"))
        profile = self.store.load()[0]
        runtime = self.root / "run" / "proton0.conf"
        runtime.parent.mkdir()
        runtime.write_text("old runtime\n")
        runtime.chmod(0o600)

        with patch.object(profiles.os, "replace", side_effect=OSError("write failed")):
            with self.assertRaises(profiles.ConfigError):
                profiles.write_runtime_config(profile, runtime, (profile,))

        self.assertEqual(runtime.read_text(), "old runtime\n")
        self.assertEqual(list(runtime.parent.glob(".proton0.conf.*")), [])

    def test_invalid_and_dangling_selection_are_explicit(self):
        self.write("proton0.conf", config("198.51.100.10:51820"))
        candidates = self.store.load()

        self.store.active_path.write_text("not a link")
        with self.assertRaisesRegex(profiles.SelectionError, "must be a symlink"):
            self.store.selected(candidates)

        self.store.active_path.unlink()
        self.store.active_path.symlink_to("profiles/missing.conf")
        with self.assertRaisesRegex(profiles.SelectionError, "dangling"):
            self.store.selected(candidates)

        self.store.active_path.unlink()
        outside = self.root.parent / "unlisted-profile.conf"
        outside.write_text(config("198.51.100.99:51820"))
        outside.chmod(0o600)
        self.addCleanup(outside.unlink)
        self.store.active_path.symlink_to(outside)
        with self.assertRaisesRegex(profiles.SelectionError, "not a declared"):
            self.store.selected(candidates)

    def test_runtime_path_cannot_overwrite_source_profile(self):
        source = self.write("proton0.conf", config("198.51.100.10:51820"))
        profile = self.store.load()[0]
        original = source.read_text()

        with self.assertRaisesRegex(profiles.ConfigError, "must not replace"):
            profiles.write_runtime_config(profile, source, (profile,))

        self.assertEqual(source.read_text(), original)

    def test_duplicate_endpoint_is_rejected_but_different_port_is_distinct(self):
        self.write("proton0.conf", config("198.51.100.10:51820"))
        self.write("profiles/other.conf", config("198.51.100.10:51821"))
        self.assertEqual(len(self.store.load()), 2)

        self.write("profiles/duplicate.conf", config("198.51.100.10:51820"))
        with self.assertRaisesRegex(profiles.ConfigError, "duplicate Endpoint"):
            self.store.load()

    def test_missing_ipv6_allowed_ips_are_rejected_before_nft(self):
        malformed = config("198.51.100.10:51820").replace(
            "AllowedIPs = 0.0.0.0/0, ::/0",
            "AllowedIPs = 0.0.0.0/0",
        )
        path = self.write("runtime.conf", malformed)
        run = Mock()

        with self.assertRaisesRegex(profiles.ConfigError, "AllowedIPs"):
            profiles.apply_endpoint_sets(path, run=run)

        run.assert_not_called()

    def test_invalid_private_key_is_rejected_without_secret_in_error(self):
        secret = "invalid-private-key-secret"
        self.write("proton0.conf", config("198.51.100.10:51820", private_key=secret))

        with self.assertRaises(profiles.ConfigError) as raised:
            self.store.load()

        self.assertNotIn(secret, str(raised.exception))

    def test_shell_hook_injection_is_rejected_before_nft(self):
        malicious = config("198.51.100.10:51820").replace(
            "[Peer]", "PostUp = nft flush ruleset; echo SHOULD_NOT_RUN\n[Peer]"
        )
        path = self.write("runtime.conf", malicious)
        run = Mock()

        with self.assertRaises(profiles.ConfigError):
            profiles.apply_endpoint_sets(path, run=run)

        run.assert_not_called()

    def test_endpoint_injection_is_rejected_before_nft(self):
        path = self.write(
            "runtime.conf",
            config("198.51.100.10:51820; nft flush ruleset"),
        )
        run = Mock()

        with self.assertRaises(profiles.ConfigError):
            profiles.apply_endpoint_sets(path, run=run)

        run.assert_not_called()

    def test_scoped_ipv6_endpoint_is_rejected_before_nft(self):
        path = self.write("runtime.conf", config("[2001:db8::1%eth0]:51820"))
        run = Mock()

        with self.assertRaises(profiles.ConfigError):
            profiles.apply_endpoint_sets(path, run=run)

        run.assert_not_called()

    def test_endpoint_nft_transaction_flushes_both_sets_and_is_one_call(self):
        runtime = self.write("runtime.conf", config("198.51.100.10:51820", dns=False))
        run = Mock()

        profiles.apply_endpoint_sets(runtime, run=run)

        run.assert_called_once()
        command = run.call_args.args[0]
        payload = run.call_args.kwargs["input"]
        self.assertEqual(command, ["nft", "-f", "-"])
        self.assertIn("flush set inet proton-killswitch proton_vpn4_endpoints", payload)
        self.assertIn("flush set inet proton-killswitch proton_vpn6_endpoints", payload)
        self.assertIn("add element inet proton-killswitch proton_vpn4_endpoints", payload)
        self.assertNotIn("proton_vpn6_endpoints {", payload)

    def test_failed_nft_transaction_does_not_trigger_follow_up_commands(self):
        runtime = self.write("runtime.conf", config("[2001:db8::42]:51820", dns=False))
        run = Mock(side_effect=subprocess.CalledProcessError(1, ["nft", "-f", "-"]))

        with self.assertRaises(subprocess.CalledProcessError):
            profiles.apply_endpoint_sets(runtime, run=run)

        run.assert_called_once()
        self.assertEqual(run.call_args.kwargs["input"].count("flush set"), 2)

    def test_profile_repr_does_not_contain_secret_text(self):
        secret = base64.b64encode(bytes([7]) * 32).decode()
        path = self.write("proton0.conf", config("198.51.100.10:51820", private_key=secret))
        profile = self.store.load()[0]

        self.assertNotIn(secret, repr(profile))
        self.assertNotIn("PrivateKey", repr(profile))
        self.assertEqual(profile.text, path.read_text())


class CommandTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        path = self.root / "proton0.conf"
        path.write_text(config("198.51.100.10:51820"))
        path.chmod(0o600)

    def test_validate_is_read_only_and_requires_alternatives_when_requested(self):
        output = io.StringIO()
        with contextlib.redirect_stdout(output), contextlib.redirect_stderr(io.StringIO()):
            status = profiles.main(
                ["--state-dir", str(self.root), "validate", "--require-alternatives"]
            )
        self.assertEqual(status, 1)
        self.assertFalse((self.root / "active.conf").exists())
        self.assertNotIn(PRIVATE_KEY, output.getvalue())

        extra = self.root / "profiles" / "backup.conf"
        extra.parent.mkdir()
        extra.write_text(config("198.51.100.11:51820"))
        extra.chmod(0o600)
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = profiles.main(["--state-dir", str(self.root), "validate"])
        self.assertEqual(status, 0)
        self.assertIn("primary 198.51.100.10:51820", output.getvalue())
        self.assertIn("backup 198.51.100.11:51820", output.getvalue())
        self.assertIn("count 2", output.getvalue())


if __name__ == "__main__":
    unittest.main()
