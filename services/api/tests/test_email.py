from unittest.mock import MagicMock, patch

from app.core.config import Settings
from app.services.email import SmtpEmailSender


def test_smtp_delivers_reset_code_without_logging_it() -> None:
    settings = Settings(
        environment="testing", smtp_host="localhost", smtp_port=1025, smtp_security="none"
    )
    with patch("app.services.email.smtplib.SMTP") as smtp:
        connection = MagicMock()
        smtp.return_value.__enter__.return_value = connection
        connection.send_message.return_value = {}
        result = SmtpEmailSender(settings).send_password_reset("person@example.com", "private-code")
        message = connection.send_message.call_args.args[0]
        assert message["To"] == "person@example.com"
        assert "private-code" in message.get_content()
        assert result.accepted_for_delivery


def test_smtp_failure_does_not_claim_delivery() -> None:
    settings = Settings(environment="testing", smtp_host="localhost", smtp_security="none")
    with patch("app.services.email.smtplib.SMTP", side_effect=OSError("unavailable")):
        assert (
            not SmtpEmailSender(settings)
            .send_password_reset("person@example.com", "private-code")
            .accepted_for_delivery
        )
