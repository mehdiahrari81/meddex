import smtplib
import ssl
from dataclasses import dataclass
from email.message import EmailMessage

from app.core.config import Settings
from app.core.logging import get_logger


@dataclass(frozen=True)
class DeliveryResult:
    accepted_for_delivery: bool
    provider_reference: str | None = None


class EmailSender:
    def send_password_reset(self, email: str, token: str) -> DeliveryResult:
        raise NotImplementedError


class DevelopmentEmailSender(EmailSender):
    """Non-delivery adapter: it never claims that a production email was sent."""

    def send_password_reset(self, email: str, token: str) -> DeliveryResult:
        get_logger().warning(
            "password_reset_delivery_unavailable",
            email_domain=email.rsplit("@", maxsplit=1)[-1],
        )
        return DeliveryResult(accepted_for_delivery=False)


class SmtpEmailSender(EmailSender):
    def __init__(self, settings: Settings) -> None:
        self.settings = settings

    def send_password_reset(self, email: str, token: str) -> DeliveryResult:
        settings = self.settings
        if not settings.smtp_host:
            return DeliveryResult(accepted_for_delivery=False)
        message = EmailMessage()
        message["From"] = str(settings.smtp_sender)
        message["To"] = email
        message["Subject"] = "Reset your MediExplain password"
        message.set_content(
            "A password reset was requested for your MediExplain account.\n\n"
            "Open MediExplain → Forgot password → Enter reset code, and paste this code:\n\n"
            f"{token}\n\n"
            f"This code expires in {settings.password_reset_minutes} minutes "
            "and can be used once.\n"
            "If you did not request a reset, ignore this email.\n"
        )
        try:
            connection: smtplib.SMTP
            if settings.smtp_security == "ssl":
                connection = smtplib.SMTP_SSL(
                    settings.smtp_host,
                    settings.smtp_port,
                    timeout=settings.smtp_timeout_seconds,
                    context=ssl.create_default_context(),
                )
            else:
                connection = smtplib.SMTP(
                    settings.smtp_host,
                    settings.smtp_port,
                    timeout=settings.smtp_timeout_seconds,
                )
            with connection as smtp:
                if settings.smtp_security == "starttls":
                    smtp.starttls(context=ssl.create_default_context())
                if settings.smtp_username and settings.smtp_password:
                    smtp.login(settings.smtp_username, settings.smtp_password.get_secret_value())
                refused = smtp.send_message(message)
            return DeliveryResult(accepted_for_delivery=not refused)
        except (OSError, smtplib.SMTPException):
            get_logger().warning("password_reset_delivery_failed")
            return DeliveryResult(accepted_for_delivery=False)
