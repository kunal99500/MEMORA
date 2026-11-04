import logging
import smtplib
from email.message import EmailMessage

from app.core.config import get_settings

logger = logging.getLogger(__name__)


def send_password_reset_email(email: str, code: str) -> None:
    settings = get_settings()
    message = EmailMessage()
    message['Subject'] = 'Your MEMORA password reset code'
    message['From'] = settings.smtp_from_email
    message['To'] = email
    message.set_content(
        f'Your MEMORA password reset code is {code}. '
        'It expires in 10 minutes. If you did not request this, ignore this email.'
    )

    try:
        with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=15) as smtp:
            if settings.smtp_starttls:
                smtp.starttls()
            if settings.smtp_username:
                smtp.login(settings.smtp_username, settings.smtp_password)
            smtp.send_message(message)
    except (OSError, smtplib.SMTPException):
        logger.exception('Could not send a MEMORA password reset email')
