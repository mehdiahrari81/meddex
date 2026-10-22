import importlib.util
import unittest
from pathlib import Path
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "presentation", Path(__file__).resolve().parents[1] / "presentation.py"
)
presentation = importlib.util.module_from_spec(spec)
spec.loader.exec_module(presentation)


class PresentationTests(unittest.TestCase):
    def test_starts_existing_database_before_api_without_replacing_data(self):
        services = {"api": ("api-id", "exited"), "postgres": ("db-id", "exited")}
        with (
            patch.object(presentation, "command") as call,
            patch.object(presentation, "healthy", return_value=True),
        ):
            presentation.start_existing(services)
        self.assertEqual(call.call_args_list[0].args, ("docker", "start", "db-id"))
        self.assertEqual(call.call_args_list[1].args, ("docker", "start", "api-id"))
        self.assertEqual(call.call_count, 2)

    def test_check_only_never_starts_stopped_containers(self):
        with (
            patch.object(presentation, "command") as call,
            self.assertRaisesRegex(RuntimeError, "postgres is stopped"),
        ):
            presentation.start_existing(
                {"postgres": ("db-id", "exited")}, check_only=True
            )
        call.assert_not_called()

    def test_project_selection_rejects_missing_or_ambiguous_existing_services(self):
        for rows in [
            "",
            "id1\tapi\trunning\nid2\tapi\trunning\nid3\tpostgres\trunning",
        ]:
            with (
                self.subTest(rows=rows),
                patch.object(presentation, "command", return_value=rows),
                self.assertRaises(RuntimeError),
            ):
                presentation.existing_services("meddex")

    def test_automatic_address_uses_hostname_not_current_wifi_ip(self):
        with patch.object(presentation, "command", return_value="my-mac") as call:
            self.assertEqual(
                presentation.automatic_url(8000), "http://my-mac.local:8000/api/v1/"
            )
        call.assert_called_once_with("scutil", "--get", "LocalHostName")

    def test_loopback_only_port_cannot_be_mistaken_for_lan_readiness(self):
        with (
            patch.object(presentation, "command", return_value="127.0.0.1:8000"),
            self.assertRaisesRegex(RuntimeError, "no IPv4 LAN"),
        ):
            presentation.api_port("api-id")
        with patch.object(
            presentation, "command", return_value="0.0.0.0:8123\n[::]:8123"
        ):
            self.assertEqual(presentation.api_port("api-id"), 8123)

    def test_wifi_monitor_reads_new_address_after_a_network_change(self):
        with patch.object(
            presentation,
            "command",
            side_effect=[
                "Hardware Port: Wi-Fi\nDevice: en1\n",
                "192.168.1.20",
                "Hardware Port: Wi-Fi\nDevice: en1\n",
                "10.34.116.118",
            ],
        ):
            self.assertEqual(presentation.current_wifi_ip(), "192.168.1.20")
            self.assertEqual(presentation.current_wifi_ip(), "10.34.116.118")

    def test_wifi_monitor_excludes_usb_link_local_and_public_addresses(self):
        for address in ["169.254.1.2", "127.0.0.1", "8.8.8.8"]:
            with (
                self.subTest(address=address),
                patch.object(
                    presentation,
                    "command",
                    side_effect=[
                        "Hardware Port: Wi-Fi\nDevice: en0\n",
                        address,
                    ],
                ),
            ):
                self.assertIsNone(presentation.current_wifi_ip())


if __name__ == "__main__":
    unittest.main()
