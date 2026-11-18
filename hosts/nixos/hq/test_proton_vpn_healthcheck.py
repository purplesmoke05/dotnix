import base64
import contextlib
from collections import deque
import errno
import importlib.util
import io
from pathlib import Path
import socket
import ssl
import struct
import subprocess
import sys
import tempfile
import threading
import unittest
from dataclasses import dataclass
from unittest.mock import MagicMock, Mock, call, patch


module_dir = str(Path(__file__).parent)
if module_dir not in sys.path:
    sys.path.insert(0, module_dir)

spec = importlib.util.spec_from_file_location(
    "proton_healthcheck", Path(__file__).with_name("proton-vpn-healthcheck.py")
)
health = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = health
spec.loader.exec_module(health)


@dataclass(frozen=True)
class FakeProfile:
    name: str
    private_key: str = "TOP-SECRET-PRIVATE-KEY"


class FakeProfileStore:
    """Small in-memory store with the production store's public contract."""

    def __init__(self, names=("first", "second", "third")):
        self.records = tuple(FakeProfile(name) for name in names)
        self.current_name = self.records[0].name
        self.selections = []

    def load(self):
        return self.records

    def selected(self, candidates):
        return next(profile for profile in candidates if profile.name == self.current_name)

    def select(self, profile):
        self.selections.append(profile.name)
        self.current_name = profile.name


class CommandRunner:
    def __init__(self, status="active", invocation_id="first"):
        self.status = (status, invocation_id)
        self.next_statuses = deque()
        self.commands = []
        self.restart_error = None

    def queue_status(self, *statuses):
        self.next_statuses.extend(statuses)

    def __call__(self, command, **kwargs):
        self.commands.append(list(command))
        if command[:2] == ["systemctl", "show"]:
            if self.next_statuses:
                self.status = self.next_statuses.popleft()
            active_state, invocation_id = self.status
            output = f"ActiveState={active_state}\nInvocationID={invocation_id}\n"
            return subprocess.CompletedProcess(command, 0, output, "")
        if command[:2] == ["systemctl", "restart"] and self.restart_error is not None:
            raise self.restart_error
        return subprocess.CompletedProcess(command, 0, "", "")

    def restarts(self):
        return [command for command in self.commands if command[:2] == ["systemctl", "restart"]]


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.path = Path(temporary.name) / "state.json"
        self.runner = CommandRunner()
        self.profiles = FakeProfileStore()
        self.output = io.StringIO()
        # Keep expected failure diagnostics out of the test report.
        self.enterContext(contextlib.redirect_stdout(self.output))

    def tick(self, reachable, now, *, profiles=None, callback=None, status=None, primary=False, primary_check=None):
        if status is not None:
            self.runner.queue_status(status)
        callback = callback or Mock(return_value=reachable)
        health.check_once(
            "proton0",
            self.path,
            profiles=profiles or self.profiles,
            run=self.runner,
            check=callback,
            clock=lambda: now,
            primary_check=primary_check or Mock(return_value=(primary, "test probe")),
        )
        return callback

    def test_three_consecutive_failures_restart_and_record_diagnostics(self):
        profiles = FakeProfileStore(("only",))
        for now in (100, 130):
            self.tick(False, now, profiles=profiles)
        self.assertEqual(self.runner.restarts(), [])

        self.tick(False, 160, profiles=profiles)

        self.assertEqual(
            self.runner.restarts(),
            [["systemctl", "restart", "--no-block", "wg-quick-proton0.service"]],
        )
        self.assertIn(["wg", "show", "proton0", "latest-handshakes"], self.runner.commands)
        state = health.read_state(self.path)
        self.assertEqual(state.last_restart, 160)
        self.assertEqual(state.pending_profile, "only")

    def test_a_success_breaks_the_failure_streak(self):
        for reachable, now in (
            (False, 100),
            (False, 130),
            (True, 160),
            (False, 190),
            (False, 220),
        ):
            self.tick(reachable, now)

        self.assertEqual(self.runner.restarts(), [])
        state = health.read_state(self.path)
        self.assertEqual(state.failures, 2)
        self.assertEqual(state.attempted_profiles, ())
        self.assertEqual(self.profiles.current_name, "first")

    def test_queued_restart_waits_for_same_invocation_and_acknowledges_new_one(self):
        profiles = FakeProfileStore(("first", "second"))
        for now in (100, 130, 160):
            self.tick(False, now, profiles=profiles)

        self.assertEqual(profiles.current_name, "second")
        state = health.read_state(self.path)
        self.assertEqual(state.pending_profile, "second")
        self.assertEqual(state.invocation_id, "first")

        # systemd has not activated the queued unit yet: don't probe it again.
        check = self.tick(True, 190, profiles=profiles, status=("active", "first"))
        check.assert_not_called()
        self.assertEqual(health.read_state(self.path).pending_profile, "second")

        # A new invocation acknowledges the activation and clears pending state.
        check = self.tick(True, 220, profiles=profiles, status=("active", "second"))
        check.assert_called_once_with("proton0")
        state = health.read_state(self.path)
        self.assertEqual(state.invocation_id, "second")
        self.assertEqual(state.pending_profile, None)
        self.assertEqual(state.failures, 0)

    def test_rotation_tries_each_candidate_before_cooldown(self):
        profiles = FakeProfileStore(("first", "second", "third"))
        for now in (100, 130, 160):
            self.tick(False, now, profiles=profiles)
        self.assertEqual(profiles.current_name, "second")

        self.runner.queue_status(("active", "second"))
        for now in (190, 220, 250):
            self.tick(False, now, profiles=profiles)
        self.assertEqual(profiles.current_name, "third")

        self.runner.queue_status(("active", "third"))
        for now in (280, 310, 340):
            self.tick(False, now, profiles=profiles)
        self.assertEqual(len(self.runner.restarts()), 2)
        state = health.read_state(self.path)
        self.assertEqual(state.attempted_profiles, ("first", "second", "third"))
        self.assertEqual(state.failures, 3)

        self.tick(False, 549, profiles=profiles)
        self.assertEqual(len(self.runner.restarts()), 2)
        self.tick(False, 550, profiles=profiles)
        self.assertEqual(len(self.runner.restarts()), 3)
        self.assertEqual(profiles.selections, ["second", "third", "first"])

    def test_success_clears_cycle_and_keeps_current_profile_sticky(self):
        profiles = FakeProfileStore(("first", "second", "third"))
        for now in (100, 130, 160):
            self.tick(False, now, profiles=profiles)
        self.runner.queue_status(("active", "second"))
        self.tick(True, 190, profiles=profiles)
        self.assertEqual(profiles.current_name, "second")
        state = health.read_state(self.path)
        self.assertEqual(state.attempted_profiles, ())
        self.assertEqual(state.pending_profile, None)

        for now in (220, 250, 280):
            self.tick(False, now, profiles=profiles)
        self.assertEqual(profiles.current_name, "third")
        self.assertEqual(profiles.selections, ["second", "third"])

    def test_failed_unit_after_queued_restart_is_visible_without_rotation(self):
        profiles = FakeProfileStore(("first", "second", "third"))
        for now in (100, 130, 160):
            self.tick(False, now, profiles=profiles)
        check = Mock(side_effect=AssertionError("failed unit must not be probed"))

        with self.assertRaises(RuntimeError):
            self.tick(False, 190, profiles=profiles, callback=check, status=("failed", "first"))

        self.assertEqual(check.call_count, 0)
        self.assertEqual(profiles.current_name, "second")
        self.assertEqual(len(self.runner.restarts()), 1)
        self.assertEqual(health.read_state(self.path).pending_profile, "second")

    def test_manual_restart_with_new_invocation_resets_failure_streak(self):
        self.tick(False, 100)
        self.tick(False, 130)
        self.tick(False, 160, status=("active", "manual-restart"))

        self.assertEqual(self.runner.restarts(), [])
        state = health.read_state(self.path)
        self.assertEqual(state.failures, 1)
        self.assertEqual(state.attempted_profiles, ())

    def test_inactive_vpn_is_not_probed_or_started(self):
        self.runner.queue_status(("inactive", ""))
        check = Mock(side_effect=AssertionError("must not probe a stopped VPN"))

        self.tick(False, 100, callback=check)

        check.assert_not_called()
        self.assertEqual(self.runner.restarts(), [])
        self.assertFalse(self.path.exists())

    def test_inactive_vpn_clears_stale_state_without_autostarting(self):
        self.path.write_text(
            '{"invocation_id":"old","failures":3,"last_restart":100,'
            '"attempted_profiles":["first"],"pending_profile":"second"}'
        )
        self.runner.queue_status(("inactive", "manual-stop"))

        self.tick(False, 200)

        self.assertEqual(health.read_state(self.path), health.State("old", 0, 100, (), None))
        self.assertEqual(self.runner.restarts(), [])

    def test_stop_during_diagnostics_cancels_restart(self):
        self.tick(False, 100)
        self.tick(False, 130)
        self.runner.queue_status(("active", "first"), ("inactive", ""))

        self.tick(False, 160)

        self.assertEqual(self.runner.restarts(), [])
        self.assertIsNone(health.read_state(self.path).pending_profile)

    def test_profile_change_during_diagnostics_cancels_restart(self):
        profiles = FakeProfileStore(("first", "second"))
        self.tick(False, 100, profiles=profiles)
        self.tick(False, 130, profiles=profiles)

        def run(command, **kwargs):
            result = self.runner(command, **kwargs)
            if command[:1] == ["wg"]:
                profiles.current_name = "second"
            return result

        health.check_once(
            "proton0",
            self.path,
            profiles=profiles,
            run=run,
            check=Mock(return_value=False),
            clock=lambda: 160,
        )

        self.assertEqual(self.runner.restarts(), [])
        self.assertIsNone(health.read_state(self.path).pending_profile)

    def test_rejected_restart_is_visible_and_retains_cooldown(self):
        profiles = FakeProfileStore(("only",))
        self.tick(False, 100, profiles=profiles)
        self.tick(False, 130, profiles=profiles)
        self.runner.restart_error = subprocess.CalledProcessError(1, "systemctl restart")
        with self.assertRaises(subprocess.CalledProcessError):
            self.tick(False, 160, profiles=profiles)

        state = health.read_state(self.path)
        self.assertEqual(state.last_restart, 160)
        self.assertIsNone(state.pending_profile)
        self.assertEqual(profiles.current_name, "only")
        self.runner.restart_error = None
        for now in (190, 220, 459):
            self.tick(False, now, profiles=profiles)
        self.assertEqual(len(self.runner.restarts()), 1)

    def test_profile_selection_error_rolls_back_and_retains_cooldown(self):
        class InvalidTargetStore(FakeProfileStore):
            def select(self, profile):
                if profile.name == "second":
                    raise health.ConfigError("invalid selected profile")
                super().select(profile)

        profiles = InvalidTargetStore(("first", "second"))
        self.tick(False, 100, profiles=profiles)
        self.tick(False, 130, profiles=profiles)
        with self.assertRaises(health.ConfigError):
            self.tick(False, 160, profiles=profiles)

        state = health.read_state(self.path)
        self.assertEqual(state.last_restart, 160)
        self.assertIsNone(state.pending_profile)
        self.assertEqual(profiles.current_name, "first")
        self.assertEqual(profiles.selections, ["first"])

    def test_diagnostic_timeout_does_not_prevent_recovery(self):
        profiles = FakeProfileStore(("only",))
        self.tick(False, 100, profiles=profiles)
        self.tick(False, 130, profiles=profiles)

        def run(command, **kwargs):
            if command[0] == "wg":
                raise subprocess.TimeoutExpired(command, 5)
            return self.runner(command, **kwargs)

        health.check_once(
            "proton0",
            self.path,
            profiles=profiles,
            run=run,
            check=Mock(return_value=False),
            clock=lambda: 160,
        )
        self.assertEqual(len(self.runner.restarts()), 1)
        self.assertIn("diagnostic timed out", self.output.getvalue())

    def test_corrupt_state_is_not_silently_reset(self):
        self.path.write_text("{broken")
        with self.assertRaises(ValueError):
            self.tick(False, 100)
        self.assertEqual(self.runner.restarts(), [])

    def test_old_state_json_uses_defaults_for_new_fields(self):
        self.path.write_text('{"invocation_id":"old","failures":2,"last_restart":12.5}')

        state = health.read_state(self.path)

        self.assertEqual(state, health.State("old", 2, 12.5, (), None))

    def fail_over(self, profiles, start):
        for now in (start, start + 30, start + 60):
            self.tick(False, now, profiles=profiles)

    def stay_healthy(self, profiles, start, end, *, primary=True):
        for now in range(start, end + 1, 30):
            self.tick(True, now, profiles=profiles, primary=primary)

    def test_backup_fails_back_once_primary_stays_healthy(self):
        profiles = FakeProfileStore(("first", "second"))
        self.fail_over(profiles, 100)
        self.tick(True, 190, profiles=profiles, status=("active", "second"), primary=True)
        due = 190 + health.FAILBACK_AFTER
        self.stay_healthy(profiles, 220, due - 30)
        self.assertEqual(profiles.selections, ["second"])

        self.tick(True, due, profiles=profiles, primary=True)

        self.assertEqual(profiles.selections, ["second", "first"])
        self.assertEqual(len(self.runner.restarts()), 2)
        state = health.read_state(self.path)
        self.assertEqual(state.pending_profile, "first")
        self.assertEqual(state.failback_from, "second")
        output = self.output.getvalue()
        self.assertIn("first is reachable through the probe tunnel", output)
        self.assertIn("failback queued: wg-quick-proton0.service; profile=second -> first", output)

    def test_failed_primary_probe_restarts_the_healthy_period(self):
        profiles = FakeProfileStore(("first", "second"))
        profiles.current_name = "second"
        self.stay_healthy(profiles, 100, 400)
        self.tick(True, 430, profiles=profiles, primary=False)
        self.assertIn("first probe failed; staying on second: test probe", self.output.getvalue())
        self.stay_healthy(profiles, 460, 460 + health.FAILBACK_AFTER - 30)
        self.assertEqual(profiles.selections, [])

        self.tick(True, 460 + health.FAILBACK_AFTER, profiles=profiles, primary=True)

        self.assertEqual(profiles.selections, ["first"])

    def test_primary_probe_failure_is_logged_when_a_streak_starts(self):
        profiles = FakeProfileStore(("first", "second"))
        profiles.current_name = "second"
        message = "first probe failed; staying on second: test probe"
        for now in (100, 130, 160):
            self.tick(True, now, profiles=profiles, primary=False)
        self.assertEqual(self.output.getvalue().count(message), 1)

        self.tick(True, 190, profiles=profiles, primary=True)
        self.tick(True, 220, profiles=profiles, primary=False)
        self.assertEqual(self.output.getvalue().count(message), 2)

        self.tick(True, 220 + health.PRIMARY_PROBE_GAP + 1, profiles=profiles, primary=False)
        self.assertEqual(self.output.getvalue().count(message), 3)

    def test_long_gap_between_primary_probes_restarts_the_healthy_period(self):
        profiles = FakeProfileStore(("first", "second"))
        profiles.current_name = "second"
        self.tick(True, 100, profiles=profiles, primary=True)
        resumed = 100 + health.PRIMARY_PROBE_GAP + 1

        self.tick(True, resumed, profiles=profiles, primary=True)

        self.assertEqual(health.read_state(self.path).primary_healthy_since, resumed)

    def test_failed_failback_returns_to_last_healthy_backup_and_doubles_the_period(self):
        profiles = FakeProfileStore(("first", "second", "third"))
        self.fail_over(profiles, 100)
        self.runner.queue_status(("active", "second"))
        self.fail_over(profiles, 190)
        self.tick(True, 280, profiles=profiles, status=("active", "third"), primary=True)
        due = 280 + health.FAILBACK_AFTER
        self.stay_healthy(profiles, 310, due)
        self.assertEqual(profiles.current_name, "first")

        self.runner.queue_status(("active", "first-again"))
        self.fail_over(profiles, due + 30)

        self.assertEqual(profiles.selections, ["second", "third", "first", "third"])
        state = health.read_state(self.path)
        self.assertEqual(state.failback_after, 2 * health.FAILBACK_AFTER)
        self.assertIsNone(state.failback_from)

    def test_failback_period_is_capped(self):
        profiles = FakeProfileStore(("first", "second"))
        self.path.write_text(
            '{"invocation_id":"first","failures":2,"last_restart":null,'
            f'"failback_after":{health.FAILBACK_AFTER_MAX},"last_failback":90}}'
        )

        self.tick(False, 100, profiles=profiles)

        self.assertEqual(health.read_state(self.path).failback_after, health.FAILBACK_AFTER_MAX)

    def test_primary_that_stays_healthy_resets_the_period(self):
        profiles = FakeProfileStore(("first", "second"))
        self.fail_over(profiles, 100)
        self.tick(True, 190, profiles=profiles, status=("active", "second"), primary=True)
        due = 190 + health.FAILBACK_AFTER
        self.stay_healthy(profiles, 220, due)
        self.tick(True, due + 30, profiles=profiles, status=("active", "first-again"))

        later = due + health.FAILBACK_STABLE
        self.fail_over(profiles, later)

        self.assertEqual(profiles.current_name, "second")
        self.assertEqual(health.read_state(self.path).failback_after, health.FAILBACK_AFTER)

    def test_active_primary_is_not_probed_through_a_second_tunnel(self):
        primary_check = Mock(side_effect=AssertionError("the active primary must not be probed again"))

        self.tick(True, 100, primary_check=primary_check)

        primary_check.assert_not_called()

    def test_unhealthy_backup_skips_the_primary_probe_and_restarts_the_period(self):
        profiles = FakeProfileStore(("first", "second"))
        profiles.current_name = "second"
        self.tick(True, 100, profiles=profiles, primary=True)
        primary_check = Mock(side_effect=AssertionError("primary must not be probed while the backup fails"))

        self.tick(False, 130, profiles=profiles, primary_check=primary_check)

        primary_check.assert_not_called()
        self.assertIsNone(health.read_state(self.path).primary_healthy_since)

    def test_unit_change_during_the_check_cancels_failback(self):
        profiles = FakeProfileStore(("first", "second"))
        profiles.current_name = "second"
        self.path.write_text(
            '{"invocation_id":"first","failures":0,"last_restart":null,'
            '"primary_healthy_since":100,"primary_checked_at":680}'
        )
        self.runner.queue_status(("active", "first"), ("active", "manual-restart"))

        self.tick(True, 100 + health.FAILBACK_AFTER, profiles=profiles, primary=True)

        self.assertEqual(self.runner.restarts(), [])
        self.assertEqual(profiles.current_name, "second")

    def test_inactive_vpn_clears_failback_state(self):
        self.path.write_text(
            '{"invocation_id":"old","failures":0,"last_restart":null,"failback_from":"second",'
            '"primary_healthy_since":50,"primary_checked_at":60}'
        )
        self.runner.queue_status(("inactive", ""))

        self.tick(True, 100)

        state = health.read_state(self.path)
        self.assertIsNone(state.failback_from)
        self.assertIsNone(state.primary_healthy_since)
        self.assertIsNone(state.primary_checked_at)

    def test_recovery_logs_do_not_expose_profile_secret_fields(self):
        profiles = FakeProfileStore(("only",))
        for now in (100, 130, 160):
            self.tick(False, now, profiles=profiles)

        self.assertNotIn("TOP-SECRET-PRIVATE-KEY", self.output.getvalue())


PROBE_PRIVATE_KEY = base64.b64encode(bytes([9]) * 32).decode()
PRIMARY = sys.modules["proton_vpn_profiles"].Profile(
    "primary",
    Path("/var/lib/proton-vpn/proton0.conf"),
    "198.51.100.10",
    51820,
    "[Interface]\n"
    f"PrivateKey = {PROBE_PRIVATE_KEY}\n"
    "Address = 10.2.0.2/32, 2a07:b944::2:2/128\n"
    "DNS = 10.2.0.1\n"
    "[Peer]\n"
    f"PublicKey = {base64.b64encode(bytes([8]) * 32).decode()}\n"
    "AllowedIPs = 0.0.0.0/0, ::/0\n"
    "Endpoint = 198.51.100.10:51820\n",
)


class PrimaryPathRunner:
    def __init__(self, *, fwmark="0xca6c", probe_exits=(0,), fail=None):
        self.fwmark = fwmark
        # The last exit code repeats once the sequence runs out.
        self.probe_exits = list(probe_exits)
        self.fail = fail
        self.calls = []

    def __call__(self, command, **kwargs):
        self.calls.append((list(command), kwargs.get("input")))
        if command[:2] == ["wg", "show"]:
            return subprocess.CompletedProcess(command, 0, f"{self.fwmark}\n", "")
        if self.fail is not None and command[: len(self.fail)] == self.fail and kwargs.get("check"):
            raise subprocess.CalledProcessError(1, command, "", f"Line unrecognized: `PrivateKey = {PROBE_PRIVATE_KEY}`")
        if command[:3] == ["ip", "netns", "exec"]:
            exit_code = self.probe_exits.pop(0) if len(self.probe_exits) > 1 else self.probe_exits[0]
            if exit_code == 0:
                return subprocess.CompletedProcess(command, 0, f"{health.PROBE_INTERFACE}: reachable\n", "")
            output = (f"probe failed: {health.PROBE_INTERFACE} -> 1.1.1.1:443: EOF occurred in violation of protocol\n"
                      f"{health.PROBE_INTERFACE}: unreachable\n")
            return subprocess.CompletedProcess(command, exit_code, output, "")
        return subprocess.CompletedProcess(command, 0, "", "")

    def commands(self):
        return [command for command, _ in self.calls]

    def probes(self):
        return [command for command in self.commands() if command[:3] == ["ip", "netns", "exec"]]


class FakeClock:
    """A monotonic clock that only moves when the code under test sleeps."""

    def __init__(self, now=1000.0):
        self.now = now
        self.sleeps = []

    def __call__(self):
        return self.now

    def sleep(self, seconds):
        self.sleeps.append(seconds)
        self.now += seconds


class PrimaryPathTests(unittest.TestCase):
    def setUp(self):
        self.output = io.StringIO()
        self.enterContext(contextlib.redirect_stdout(self.output))

    def test_probe_tunnel_runs_in_its_own_namespace_and_is_removed(self):
        runner = PrimaryPathRunner()

        reachable, detail = health.primary_path_reachable(PRIMARY, "proton0", run=runner)

        self.assertTrue(reachable)
        self.assertEqual(detail, "pvpn-probe0: reachable")
        namespace, interface = health.PROBE_NAMESPACE, health.PROBE_INTERFACE
        cleanup = [["ip", "netns", "delete", namespace], ["ip", "link", "delete", interface]]
        setup = [
            ["ip", "netns", "add", namespace],
            ["ip", "link", "add", interface, "type", "wireguard"],
            ["wg", "setconf", interface, "/dev/stdin"],
            ["ip", "link", "set", interface, "netns", namespace],
            ["ip", "-n", namespace, "address", "add", "10.2.0.2/32", "dev", interface],
            ["ip", "-n", namespace, "address", "add", "2a07:b944::2:2/128", "dev", interface],
            ["ip", "-n", namespace, "link", "set", "lo", "up"],
            ["ip", "-n", namespace, "link", "set", interface, "up"],
            ["ip", "-n", namespace, "-4", "route", "add", "default", "dev", interface],
            ["ip", "-n", namespace, "-6", "route", "add", "default", "dev", interface],
        ]
        allow = ["nft", "add", "element", "inet", "proton-killswitch", "proton_vpn4_endpoints",
                 "{ 198.51.100.10 . 51820 }"]
        commands = runner.commands()
        self.assertEqual(commands[:4], [["wg", "show", "proton0", "fwmark"], *cleanup, allow])
        self.assertEqual(commands[4:4 + len(setup)], setup)
        probe = commands[4 + len(setup)]
        self.assertEqual(probe[:4], ["ip", "netns", "exec", namespace])
        self.assertEqual(probe[-5:], ["--check-only", "--interface", interface, "--dns-server", "10.2.0.1"])
        self.assertEqual(commands[-2:], cleanup)
        setconf = next(stdin for command, stdin in runner.calls if command[:2] == ["wg", "setconf"])
        self.assertIn("FwMark = 0xca6c", setconf)
        self.assertNotIn("Address", setconf)
        self.assertFalse(any(PROBE_PRIVATE_KEY in " ".join(command) for command in commands))

    def test_wg_errors_are_not_echoed_and_the_tunnel_is_removed(self):
        runner = PrimaryPathRunner(fail=["wg", "setconf"])

        reachable, detail = health.primary_path_reachable(PRIMARY, "proton0", run=runner)

        self.assertFalse(reachable)
        self.assertEqual(detail, "probe setup failed: wg setconf pvpn-probe0")
        self.assertNotIn(PROBE_PRIVATE_KEY, detail + self.output.getvalue())
        self.assertEqual(
            runner.commands()[-2:],
            [["ip", "netns", "delete", health.PROBE_NAMESPACE], ["ip", "link", "delete", health.PROBE_INTERFACE]],
        )

    def test_probe_needs_the_main_tunnel_fwmark_to_bypass_it(self):
        runner = PrimaryPathRunner(fwmark="off")

        reachable, detail = health.primary_path_reachable(PRIMARY, "proton0", run=runner)

        self.assertFalse(reachable)
        self.assertIn("fwmark", detail)
        self.assertEqual(runner.commands(), [["wg", "show", "proton0", "fwmark"]])

    def test_fresh_session_is_retried_until_the_probe_passes(self):
        runner = PrimaryPathRunner(probe_exits=(1, 1, 0))
        clock = FakeClock()

        reachable, detail = health.primary_path_reachable(PRIMARY, "proton0", run=runner, clock=clock,
                                                          sleep=clock.sleep)

        self.assertTrue(reachable)
        self.assertEqual(detail, "pvpn-probe0: reachable")
        self.assertEqual(len(runner.probes()), 3)
        self.assertEqual(clock.sleeps, [health.PROBE_RETRY_GAP] * 2)
        # Every attempt reuses the one tunnel, so the session that settles is the one being probed.
        self.assertEqual(runner.commands().count(["ip", "netns", "add", health.PROBE_NAMESPACE]), 1)
        self.assertEqual(
            runner.commands()[-2:],
            [["ip", "netns", "delete", health.PROBE_NAMESPACE], ["ip", "link", "delete", health.PROBE_INTERFACE]],
        )

    def test_unreachable_primary_is_reported_after_the_settle_period(self):
        runner = PrimaryPathRunner(probe_exits=(1,))
        clock = FakeClock()

        reachable, detail = health.primary_path_reachable(PRIMARY, "proton0", run=runner, clock=clock,
                                                          sleep=clock.sleep)

        self.assertFalse(reachable)
        attempts = len(runner.probes())
        self.assertGreater(attempts, 1)
        # It neither gives up early nor sleeps past the settle period.
        self.assertLess(sum(clock.sleeps), health.PROBE_SETTLE)
        self.assertGreaterEqual(sum(clock.sleeps) + health.PROBE_RETRY_GAP, health.PROBE_SETTLE)
        self.assertEqual(
            detail,
            f"probe failed: pvpn-probe0 -> 1.1.1.1:443: EOF occurred in violation of protocol ({attempts} attempts)",
        )
        self.assertEqual(
            runner.commands()[-2:],
            [["ip", "netns", "delete", health.PROBE_NAMESPACE], ["ip", "link", "delete", health.PROBE_INTERFACE]],
        )

    def test_check_only_can_query_an_explicit_dns_server(self):
        argv = ["proton-vpn-healthcheck.py", "--check-only", "--interface", "pvpn-probe0", "--dns-server", "10.2.0.1"]
        with patch.object(sys, "argv", argv), patch.object(health, "probe", return_value=True) as probe, patch.object(
            health, "query_dns"
        ) as query:
            self.assertEqual(health.main(), 0)
            probe.call_args.kwargs["resolve"]("pvpn-probe0", 28)

        query.assert_called_once_with("pvpn-probe0", 28, ("10.2.0.1", 53))


class ProbeTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))

    def test_one_reachable_provider_per_address_family_is_sufficient(self):
        connect = Mock(side_effect=[TimeoutError("timed out"), None, TimeoutError("timed out"), None])
        resolve = Mock(return_value=None)

        self.assertTrue(health.probe("proton0", connect=connect, resolve=resolve))
        self.assertEqual(connect.call_count, 4)
        self.assertEqual(resolve.call_args_list, [call("proton0", 1), call("proton0", 28)])

    def test_both_ipv4_providers_unreachable(self):
        connect = Mock(side_effect=OSError(errno.ENETUNREACH, "network unreachable"))
        resolve = Mock(return_value=None)

        self.assertFalse(health.probe("proton0", connect=connect, resolve=resolve))
        self.assertEqual(connect.call_count, 2)
        resolve.assert_not_called()

    def test_ipv6_failure_is_independent_from_ipv4_success(self):
        connect = Mock(
            side_effect=[
                None,
                OSError(errno.ENETUNREACH, "network unreachable"),
                OSError(errno.ENETUNREACH, "network unreachable"),
            ]
        )
        resolve = Mock(return_value=None)

        self.assertFalse(health.probe("proton0", connect=connect, resolve=resolve))
        self.assertEqual(connect.call_count, 3)
        resolve.assert_not_called()

    def test_probe_permission_error_does_not_trigger_recovery(self):
        connect = Mock(side_effect=PermissionError(errno.EPERM, "not permitted"))
        with self.assertRaises(PermissionError):
            health.probe("proton0", connect=connect, resolve=Mock())

    def test_probe_resource_error_is_visible(self):
        connect = Mock(side_effect=OSError(errno.EMFILE, "too many open files"))
        with self.assertRaises(OSError):
            health.probe("proton0", connect=connect, resolve=Mock())

    def test_probe_expected_dns_network_error_is_unreachable(self):
        connect = Mock(return_value=None)
        resolve = Mock(side_effect=OSError(errno.ETIMEDOUT, "timed out"))

        self.assertFalse(health.probe("proton0", connect=connect, resolve=resolve))
        self.assertEqual(resolve.call_count, 1)

    def test_tls_failure_is_unreachable_and_skips_dns(self):
        for error in (
            ssl.SSLEOFError(ssl.SSL_ERROR_EOF, "EOF occurred in violation of protocol"),
            ssl.SSLError("wrong version number"),
            BrokenPipeError(errno.EPIPE, "broken pipe"),
        ):
            with self.subTest(error=error):
                connect = Mock(side_effect=error)
                resolve = Mock(return_value=None)

                self.assertFalse(health.probe("proton0", connect=connect, resolve=resolve))
                self.assertEqual(connect.call_count, 2)
                resolve.assert_not_called()

    def test_connect_tls_uses_target_address_family_and_bound_interface(self):
        for target, family in (
            (("1.1.1.1", 443), socket.AF_INET),
            (("2606:4700:4700::1111", 443), socket.AF_INET6),
        ):
            with self.subTest(target=target):
                connection = Mock()
                connection.__enter__ = Mock(return_value=connection)
                connection.__exit__ = Mock(return_value=None)
                context = MagicMock()
                with patch.object(health, "bound_socket", return_value=connection) as bound, patch.object(
                    health.ssl, "SSLContext", return_value=context
                ):
                    health.connect_tls("proton0", target)
                bound.assert_called_once_with("proton0", family, socket.SOCK_STREAM)
                connection.connect.assert_called_once_with(target)
                context.wrap_socket.assert_called_once_with(connection)
                self.assertFalse(context.check_hostname)
                self.assertEqual(context.verify_mode, ssl.CERT_NONE)

    def test_bound_socket_sets_timeout_and_binds_to_interface(self):
        connection = Mock()
        with patch.object(health.socket, "socket", return_value=connection) as factory:
            result = health.bound_socket("proton0", socket.AF_INET6, socket.SOCK_DGRAM)

        factory.assert_called_once_with(socket.AF_INET6, socket.SOCK_DGRAM)
        connection.settimeout.assert_called_once_with(health.CONNECT_TIMEOUT)
        connection.setsockopt.assert_called_once_with(
            socket.SOL_SOCKET, socket.SO_BINDTODEVICE, b"proton0\0"
        )
        self.assertIs(result, connection)


class TlsHandshakeTests(unittest.TestCase):
    """A local listener acts like a VPN server that accepts TCP without reaching the target."""

    def setUp(self):
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))
        self.server = socket.create_server(("127.0.0.1", 0))
        self.addCleanup(self.server.close)

    def reachable(self, reply):
        def serve():
            connection, _ = self.server.accept()
            with connection:
                connection.recv(4096)
                reply(connection)

        thread = threading.Thread(target=serve, daemon=True)
        thread.start()
        self.addCleanup(thread.join, 5)
        target = self.server.getsockname()[:2]
        with patch.object(health, "CONNECT_TIMEOUT", 0.2):
            return health.network_check("tls", lambda: health.connect_tls("lo", target))

    def test_connection_closed_after_client_hello_is_unreachable(self):
        self.assertFalse(self.reachable(lambda connection: None))

    def test_silent_peer_is_unreachable(self):
        self.assertFalse(self.reachable(lambda connection: connection.recv(1)))

    def test_non_tls_reply_is_unreachable(self):
        self.assertFalse(
            self.reachable(lambda connection: connection.sendall(b"HTTP/1.1 400 Bad Request\r\n\r\n"))
        )


class DnsSocket:
    def __init__(self, response_factory):
        self.response_factory = response_factory
        self.request = None
        self.connected_to = None

    def __enter__(self):
        return self

    def __exit__(self, *exc_info):
        return None

    def connect(self, server):
        self.connected_to = server

    def send(self, request):
        self.request = request

    def recv(self, size):
        return self.response_factory(self.request)


def dns_response(request, *, response_id=None, flags=0x8180, questions=1, answers=1, question=None):
    identifier = struct.unpack("!H", request[:2])[0] if response_id is None else response_id
    question = request[12:] if question is None else question
    header = struct.pack("!6H", identifier, flags, questions, answers, 0, 0)
    return header + question + b"\x00"


class DnsTests(unittest.TestCase):
    def setUp(self):
        self.enterContext(contextlib.redirect_stdout(io.StringIO()))

    def query_with_response(self, response_factory, server=("10.2.0.1", 53), record_type=1):
        connection = DnsSocket(response_factory)
        with patch.object(health, "secrets") as secrets, patch.object(
            health, "bound_socket", return_value=connection
        ) as bound:
            secrets.randbelow.return_value = 0x1234
            health.query_dns("proton0", record_type, server)
        return connection, bound

    def test_query_dns_sends_requested_record_type_and_accepts_matching_answer(self):
        connection, bound = self.query_with_response(lambda request: dns_response(request), record_type=28)

        bound.assert_called_once_with("proton0", socket.AF_INET, socket.SOCK_DGRAM)
        self.assertEqual(connection.connected_to, ("10.2.0.1", 53))
        self.assertEqual(struct.unpack("!2H", connection.request[-4:]), (28, 1))

    def test_query_dns_rejects_malformed_nxdomain_truncated_and_wrong_id_responses(self):
        cases = (
            ("malformed", lambda request: dns_response(request, question=b"bad")),
            ("nxdomain", lambda request: dns_response(request, flags=0x8183)),
            ("truncated", lambda request: dns_response(request, flags=0x8380)),
            ("no answer", lambda request: dns_response(request, answers=0)),
            ("wrong transaction id", lambda request: dns_response(request, response_id=0x4321)),
        )
        for description, response_factory in cases:
            with self.subTest(response=description):
                with self.assertRaises(health.DNSResponseError):
                    self.query_with_response(response_factory)

    def test_query_dns_rejects_short_response(self):
        with self.assertRaises(health.DNSResponseError):
            self.query_with_response(lambda request: b"short")

    def test_query_dns_uses_loopback_and_address_family_for_configured_server(self):
        for server, family, device in (
            (("127.0.0.1", 53), socket.AF_INET, "lo"),
            (("2001:4860:4860::8888", 53), socket.AF_INET6, "proton0"),
        ):
            with self.subTest(server=server):
                connection, bound = self.query_with_response(
                    lambda request: dns_response(request), server=server
                )
                bound.assert_called_once_with(device, family, socket.SOCK_DGRAM)
                self.assertEqual(connection.connected_to, server)

    def test_configured_dns_is_passed_to_query_and_falls_back_on_network_error(self):
        class ResolvConf:
            def read_text(self):
                return "# managed\nnameserver 127.0.0.1\nnameserver 2001:4860:4860::8888\n"

        query = Mock(side_effect=[OSError(errno.ETIMEDOUT, "timed out"), None])
        with patch.object(health, "Path", return_value=ResolvConf()), patch.object(
            health, "query_dns", query
        ):
            health.query_configured_dns("proton0", 28)

        self.assertEqual(
            query.call_args_list,
            [
                call("proton0", 28, ("127.0.0.1", 53)),
                call("proton0", 28, ("2001:4860:4860::8888", 53)),
            ],
        )


if __name__ == "__main__":
    unittest.main()
