"""Deployment must not reintroduce an IP address that changes with Wi-Fi."""

import importlib.util
import json
import unittest
from pathlib import Path
from unittest.mock import MagicMock, patch

spec = importlib.util.spec_from_file_location(
    "ios_installer", Path(__file__).resolve().parents[1] / "install-ios-device.py"
)
installer = importlib.util.module_from_spec(spec)
spec.loader.exec_module(installer)


class AutomaticServerTests(unittest.TestCase):
    def test_installer_pins_loopback_server_public_identity_and_current_lan_only(self):
        public_key = "A" * 124
        opener = MagicMock()
        opener.open.return_value.__enter__.return_value.read.return_value = json.dumps(
            {"public_key": public_key}
        ).encode()
        with (
            patch.object(installer, "build_opener", return_value=opener),
            patch.object(
                installer,
                "wifi_api_base_url",
                return_value="http://10.141.27.28:8000/api/v1/",
            ),
        ):
            defines = installer.local_server_defines("http://my-mac.local:8000/api/v1/")
        self.assertEqual(
            defines,
            [
                f"--dart-define=LOCAL_SERVER_PUBLIC_KEY={public_key}",
                "--dart-define=LOCAL_SERVER_ADDRESSES=10.141.27.28",
            ],
        )
        self.assertTrue(
            opener.open.call_args.args[0].startswith("http://127.0.0.1:8000/")
        )

    def test_hosted_and_manual_numeric_urls_do_not_receive_local_fallback(self):
        with patch.object(installer, "build_opener") as opener:
            for url in [
                "https://api.example.com/api/v1/",
                "http://10.1.2.3:8000/api/v1/",
            ]:
                self.assertEqual(installer.local_server_defines(url), [])
        opener.assert_not_called()

    def test_automatic_uses_mac_name_without_reading_a_wifi_ip(self):
        with patch.object(
            installer.subprocess, "check_output", return_value="my-mac\n"
        ) as command:
            self.assertEqual(
                installer.automatic_api_base_url(), "http://my-mac.local:8000/api/v1/"
            )
            command.assert_called_once_with(
                ["scutil", "--get", "LocalHostName"], text=True
            )

    def test_invalid_hostname_does_not_fall_back_to_a_stale_address(self):
        for hostname in ["", "bad name", "http://elsewhere", "-invalid"]:
            with (
                self.subTest(hostname=hostname),
                patch.object(
                    installer.subprocess, "check_output", return_value=hostname
                ),
                self.assertRaises(RuntimeError),
            ):
                installer.automatic_api_base_url()

    def test_explicit_wifi_mode_still_reads_current_interface(self):
        with patch.object(
            installer.subprocess,
            "check_output",
            side_effect=["Hardware Port: Wi-Fi\nDevice: en0\n", "192.168.1.20\n"],
        ):
            self.assertEqual(
                installer.wifi_api_base_url(), "http://192.168.1.20:8000/api/v1/"
            )


if __name__ == "__main__":
    unittest.main()
