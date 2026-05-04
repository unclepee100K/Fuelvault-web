import threading
from datetime import datetime
from flask import current_app
from flask_mail import Message

# Optional Twilio import (graceful fallback if not installed)
try:
    from twilio.rest import Client
    TWILIO_AVAILABLE = True
except ImportError:
    TWILIO_AVAILABLE = False

notification_history = []

def send_email(to_email, subject, body, is_html=False):
    """Send real email using Flask-Mail (with app context)."""
    def _send():
        with current_app.app_context():
            try:
                msg = Message(subject,
                              recipients=[to_email],
                              body=body,
                              html=body if is_html else None)
                # Access mail via current_app
                current_app.extensions['mail'].send(msg)
                status = 'sent'
            except Exception as e:
                print(f"Email failed: {e}")
                status = 'failed'

            # Record in notification history
            notification_history.append({
                'type': 'email',
                'to': to_email,
                'subject': subject,
                'body': body,
                'timestamp': datetime.now().isoformat(),
                'status': status
            })
    threading.Thread(target=_send).start()


def send_sms(phone_number, message):
    """Send real SMS using Twilio (if configured)."""
    if not TWILIO_AVAILABLE:
        print("Twilio not installed. SMS not sent.")
        _record_sms(phone_number, message, 'failed (library missing)')
        return

    account_sid = current_app.config.get('TWILIO_ACCOUNT_SID')
    auth_token = current_app.config.get('TWILIO_AUTH_TOKEN')
    from_number = current_app.config.get('TWILIO_PHONE_NUMBER')

    if not account_sid or not auth_token or not from_number:
        print("Twilio credentials not configured. SMS not sent.")
        _record_sms(phone_number, message, 'failed (missing credentials)')
        return

    def _send():
        try:
            client = Client(account_sid, auth_token)
            client.messages.create(
                body=message,
                from_=from_number,
                to=phone_number
            )
            status = 'sent'
        except Exception as e:
            print(f"SMS failed: {e}")
            status = 'failed'
        _record_sms(phone_number, message, status)
    threading.Thread(target=_send).start()


def _record_sms(phone_number, message, status):
    """Helper to record SMS in notification history."""
    notification_history.append({
        'type': 'sms',
        'to': phone_number,
        'message': message,
        'timestamp': datetime.now().isoformat(),
        'status': status
    })


def send_coupon_notification(coupon_data):
    """Send coupon details via email and SMS."""
    subject = f"Fuel Coupon Issued - {coupon_data['coupon_code']}"
    body = f"""
    Dear {coupon_data['employee_name']},

    Your fuel coupon has been issued!

    Coupon Code: {coupon_data['coupon_code']}
    Vehicle: {coupon_data['vehicle_number']}
    Fuel: {coupon_data['fuel_type']}
    Amount: {coupon_data['amount']} Liters
    Valid Until: {coupon_data.get('expires_at', '7 days')}

    Present this coupon at any authorized fuel station.

    Thank you,
    FuelVault Team
    """
    if coupon_data.get('email'):
        send_email(coupon_data['email'], subject, body)
    if coupon_data.get('phone'):
        sms_body = f"Fuel coupon {coupon_data['coupon_code']} issued for {coupon_data['amount']}L {coupon_data['fuel_type']}"
        send_sms(coupon_data['phone'], sms_body)


def send_approval_notification(request, approved, notes):
    """Send approval/decline notification."""
    status = "approved" if approved else "declined"
    subject = f"Fuel Request {status.upper()} - {request.id}"
    body = f"""
    Dear {request.employee_name},

    Your fuel request has been {status}.

    Request ID: {request.id}
    Amount: {request.amount}L
    Fuel: {request.fuel_type}

    Notes: {notes if notes else 'No additional notes'}

    You can track the status in the FuelVault system.

    Thank you,
    FuelVault Team
    """
    email = request.employee.email if request.employee else None
    if email:
        send_email(email, subject, body)


def get_notification_history():
    """Return the list of notifications (for display)."""
    return notification_history