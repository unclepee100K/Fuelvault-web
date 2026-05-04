# Create the project structure for FuelVault Flask app
# Run this script in an empty directory

Write-Host "Creating FuelVault Flask project structure..." -ForegroundColor Green

# Create directories
$folders = @(
    "app",
    "app/routes",
    "app/templates",
    "app/templates/employee",
    "app/templates/hod",
    "app/templates/admin",
    "app/templates/issuer",
    "app/templates/attendant",
    "app/static/css",
    "app/utils"
)

foreach ($folder in $folders) {
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    Write-Host "Created folder: $folder"
}

# Function to write file content using single-quoted here-string
function Write-FileContent {
    param($Path, $Content)
    Set-Content -Path $Path -Value $Content -Encoding utf8
    Write-Host "Created file: $Path"
}

# 1. config.py
Write-FileContent -Path "config.py" -Content @'
import os

class Config:
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:///fuelvault.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    # For email simulation (no actual SMTP needed for now)
    MAIL_SERVER = 'smtp.example.com'
    MAIL_PORT = 587
    MAIL_USE_TLS = True
    MAIL_USERNAME = os.environ.get('MAIL_USERNAME')
    MAIL_PASSWORD = os.environ.get('MAIL_PASSWORD')
'@

# 2. app/__init__.py
Write-FileContent -Path "app/__init__.py" -Content @'
from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from config import Config

db = SQLAlchemy()
login_manager = LoginManager()
login_manager.login_view = 'auth.login'

def create_app(config_class=Config):
    app = Flask(__name__)
    app.config.from_object(config_class)

    db.init_app(app)
    login_manager.init_app(app)

    from app.routes import auth, employee, hod, admin, issuer, attendant, main
    app.register_blueprint(auth.bp)
    app.register_blueprint(employee.bp)
    app.register_blueprint(hod.bp)
    app.register_blueprint(admin.bp)
    app.register_blueprint(issuer.bp)
    app.register_blueprint(attendant.bp)
    app.register_blueprint(main.bp)

    return app
'@

# 3. app/models.py
Write-FileContent -Path "app/models.py" -Content @'
from app import db
from flask_login import UserMixin
from datetime import datetime

class User(UserMixin, db.Model):
    __tablename__ = 'users'
    username = db.Column(db.String(80), primary_key=True)
    password_hash = db.Column(db.String(128), nullable=False)
    role = db.Column(db.String(20), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    department = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120))
    phone = db.Column(db.String(20))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    is_active = db.Column(db.Boolean, default=True)

    def get_id(self):
        return self.username

class FuelRequest(db.Model):
    __tablename__ = 'fuel_requests'
    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.String(80), db.ForeignKey('users.username'), nullable=False)
    employee_name = db.Column(db.String(100), nullable=False)
    department = db.Column(db.String(100), nullable=False)
    vehicle_number = db.Column(db.String(50), nullable=False)
    vehicle_type = db.Column(db.String(50), nullable=False)
    fuel_type = db.Column(db.String(20), nullable=False)
    amount = db.Column(db.Float, nullable=False)
    purpose = db.Column(db.String(200), nullable=False)
    notes = db.Column(db.Text)
    status = db.Column(db.String(50), nullable=False, default='Pending HOD Approval')
    timestamp = db.Column(db.DateTime, default=datetime.utcnow)

    hod_approval = db.Column(db.Boolean)
    hod_notes = db.Column(db.Text)
    admin_approval = db.Column(db.Boolean)
    admin_notes = db.Column(db.Text)
    issuer_approval = db.Column(db.Boolean)
    issuer_notes = db.Column(db.Text)
    coupon_code = db.Column(db.String(50))
    issuer_timestamp = db.Column(db.DateTime)
    expires_at = db.Column(db.DateTime)
    verified_at = db.Column(db.DateTime)
    verified_by = db.Column(db.String(100))

    employee = db.relationship('User', backref='requests')

class FuelCoupon(db.Model):
    __tablename__ = 'fuel_coupons'
    coupon_code = db.Column(db.String(50), primary_key=True)
    request_id = db.Column(db.Integer, db.ForeignKey('fuel_requests.id'))
    used_at = db.Column(db.DateTime)
    is_used = db.Column(db.Boolean, default=False)
    verified_by = db.Column(db.String(100))
    station_name = db.Column(db.String(100))

    request = db.relationship('FuelRequest', backref='coupon')
'@

# 4. app/forms.py
Write-FileContent -Path "app/forms.py" -Content @'
from flask_wtf import FlaskForm
from wtforms import StringField, FloatField, SelectField, TextAreaField, PasswordField
from wtforms.validators import DataRequired, Length, NumberRange, Regexp, Optional

class LoginForm(FlaskForm):
    username = StringField('Username', validators=[DataRequired()])
    password = PasswordField('Password', validators=[DataRequired()])

class FuelRequestForm(FlaskForm):
    vehicle_number = StringField('Vehicle Number', validators=[DataRequired(), Length(max=50)])
    vehicle_type = SelectField('Vehicle Type', choices=[('Car','Car'),('Truck','Truck'),('Motorcycle','Motorcycle'),('Other','Other')], validators=[DataRequired()])
    fuel_type = SelectField('Fuel Type', choices=[('Petrol','Petrol'),('Diesel','Diesel'),('CNG','CNG')], validators=[DataRequired()])
    amount = FloatField('Amount (Liters)', validators=[DataRequired(), NumberRange(min=0.1, message='Amount must be positive')])
    purpose = SelectField('Purpose', choices=[('Official Travel','Official Travel'),('Field Work','Field Work'),('Emergency','Emergency'),('Other','Other')], validators=[DataRequired()])
    notes = TextAreaField('Additional Notes', validators=[Optional()])

class UpdateContactForm(FlaskForm):
    email = StringField('Email', validators=[Optional(), Length(max=120)])
    phone = StringField('Phone', validators=[Optional(), Length(max=20)])

class ApprovalForm(FlaskForm):
    notes = TextAreaField('Notes')

class CouponVerificationForm(FlaskForm):
    coupon_code = StringField('Coupon Code', validators=[DataRequired(), Length(min=6, max=50)])
    station_name = StringField('Station Name', validators=[DataRequired(), Length(max=100)])
'@

# 5. app/utils/__init__.py
Write-FileContent -Path "app/utils/__init__.py" -Content ''

# 6. app/utils/helpers.py
Write-FileContent -Path "app/utils/helpers.py" -Content @'
from functools import wraps
from flask import abort, flash, redirect, url_for
from flask_login import current_user

def role_required(*roles):
    def decorator(func):
        @wraps(func)
        def decorated_view(*args, **kwargs):
            if not current_user.is_authenticated:
                flash('Please log in to access this page.', 'warning')
                return redirect(url_for('auth.login'))
            if current_user.role not in roles:
                abort(403)
            return func(*args, **kwargs)
        return decorated_view
    return decorator
'@

# 7. app/utils/notifications.py
Write-FileContent -Path "app/utils/notifications.py" -Content @'
import threading
from datetime import datetime

notification_history = []

def send_email(to_email, subject, body):
    notification = {
        'type': 'email',
        'to': to_email,
        'subject': subject,
        'body': body,
        'timestamp': datetime.now().isoformat(),
        'status': 'sent'
    }
    notification_history.append(notification)
    print(f"Email sent to {to_email}: {subject}")

def send_sms(phone_number, message):
    notification = {
        'type': 'sms',
        'to': phone_number,
        'message': message,
        'timestamp': datetime.now().isoformat(),
        'status': 'sent'
    }
    notification_history.append(notification)
    print(f"SMS sent to {phone_number}: {message[:50]}...")

def send_coupon_notification(coupon_data):
    subject = f"Fuel Coupon Issued - {coupon_data['coupon_code']}"
    body = f\"\"\"
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
    \"\"\"
    if coupon_data.get('email'):
        threading.Thread(target=send_email, args=(coupon_data['email'], subject, body)).start()
    if coupon_data.get('phone'):
        sms_body = f"Fuel coupon {coupon_data['coupon_code']} issued for {coupon_data['amount']}L {coupon_data['fuel_type']}"
        threading.Thread(target=send_sms, args=(coupon_data['phone'], sms_body)).start()

def send_approval_notification(request, approved, notes):
    status = "approved" if approved else "declined"
    subject = f"Fuel Request {status.upper()} - {request.id}"
    body = f\"\"\"
    Dear {request.employee_name},

    Your fuel request has been {status}.

    Request ID: {request.id}
    Amount: {request.amount}L
    Fuel: {request.fuel_type}

    Notes: {notes if notes else 'No additional notes'}

    You can track the status in the FuelVault system.

    Thank you,
    FuelVault Team
    \"\"\"
    email = request.employee.email if request.employee else None
    if email:
        threading.Thread(target=send_email, args=(email, subject, body)).start()

def get_notification_history():
    return notification_history
'@

# 8. app/routes/__init__.py
Write-FileContent -Path "app/routes/__init__.py" -Content ''

# 9. app/routes/auth.py
Write-FileContent -Path "app/routes/auth.py" -Content @'
from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_user, logout_user, login_required, current_user
from app import db
from app.models import User
from app.forms import LoginForm
from werkzeug.security import check_password_hash

bp = Blueprint('auth', __name__)

@bp.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('main.dashboard'))
    form = LoginForm()
    if form.validate_on_submit():
        user = User.query.filter_by(username=form.username.data).first()
        if user and user.is_active and check_password_hash(user.password_hash, form.password.data):
            login_user(user)
            next_page = request.args.get('next')
            return redirect(next_page) if next_page else redirect(url_for('main.dashboard'))
        else:
            flash('Invalid username or password', 'danger')
    return render_template('login.html', form=form)

@bp.route('/logout')
@login_required
def logout():
    logout_user()
    flash('You have been logged out.', 'info')
    return redirect(url_for('auth.login'))
'@

# 10. app/routes/main.py
Write-FileContent -Path "app/routes/main.py" -Content @'
from flask import Blueprint, render_template, redirect, url_for
from flask_login import login_required, current_user
from app.utils.helpers import role_required
from app.utils.notifications import get_notification_history

bp = Blueprint('main', __name__)

@bp.route('/')
@login_required
def dashboard():
    role = current_user.role
    if role == 'Employee':
        return redirect(url_for('employee.dashboard'))
    elif role == 'HOD':
        return redirect(url_for('hod.dashboard'))
    elif role == 'Administrator':
        return redirect(url_for('admin.dashboard'))
    elif role == 'Issuer':
        return redirect(url_for('issuer.dashboard'))
    elif role == 'Attendant':
        return redirect(url_for('attendant.dashboard'))
    else:
        return redirect(url_for('auth.login'))

@bp.route('/notifications')
@login_required
def notifications():
    history = get_notification_history()
    return render_template('notifications.html', notifications=history[-20:])
'@

# 11. app/routes/employee.py
Write-FileContent -Path "app/routes/employee.py" -Content @'
from flask import Blueprint, render_template, redirect, url_for, flash, request
from flask_login import login_required, current_user
from app import db
from app.models import User, FuelRequest
from app.forms import FuelRequestForm, UpdateContactForm
from app.utils.helpers import role_required
from app.utils.notifications import send_approval_notification, send_email
from datetime import datetime, timedelta
import secrets

bp = Blueprint('employee', __name__, url_prefix='/employee')

@bp.route('/')
@login_required
@role_required('Employee')
def dashboard():
    return render_template('employee/dashboard.html', user=current_user)

@bp.route('/request', methods=['GET', 'POST'])
@login_required
@role_required('Employee')
def request_fuel():
    form = FuelRequestForm()
    if form.validate_on_submit():
        request = FuelRequest(
            employee_id=current_user.username,
            employee_name=current_user.name,
            department=current_user.department,
            vehicle_number=form.vehicle_number.data,
            vehicle_type=form.vehicle_type.data,
            fuel_type=form.fuel_type.data,
            amount=form.amount.data,
            purpose=form.purpose.data,
            notes=form.notes.data,
            status='Pending HOD Approval',
            expires_at=datetime.utcnow() + timedelta(days=7)
        )
        db.session.add(request)
        db.session.commit()
        # Send confirmation email
        if current_user.email:
            send_email(current_user.email, "Fuel Request Submitted", f"Your request ID {request.id} has been submitted.")
        flash('Fuel request submitted successfully!', 'success')
        return redirect(url_for('employee.my_requests'))
    return render_template('employee/request_form.html', form=form)

@bp.route('/my-requests')
@login_required
@role_required('Employee')
def my_requests():
    requests = FuelRequest.query.filter_by(employee_id=current_user.username).order_by(FuelRequest.timestamp.desc()).all()
    return render_template('employee/requests.html', requests=requests)

@bp.route('/update-contact', methods=['GET', 'POST'])
@login_required
@role_required('Employee')
def update_contact():
    form = UpdateContactForm()
    if form.validate_on_submit():
        current_user.email = form.email.data
        current_user.phone = form.phone.data
        db.session.commit()
        flash('Contact information updated!', 'success')
        return redirect(url_for('employee.dashboard'))
    form.email.data = current_user.email
    form.phone.data = current_user.phone
    return render_template('employee/update_contact.html', form=form)
'@

# 12. app/routes/hod.py
Write-FileContent -Path "app/routes/hod.py" -Content @'
from flask import Blueprint, render_template, request, flash, redirect, url_for
from flask_login import login_required, current_user
from app import db
from app.models import FuelRequest
from app.utils.helpers import role_required
from app.utils.notifications import send_approval_notification

bp = Blueprint('hod', __name__, url_prefix='/hod')

@bp.route('/')
@login_required
@role_required('HOD')
def dashboard():
    pending = FuelRequest.query.filter_by(status='Pending HOD Approval').all()
    return render_template('hod/dashboard.html', requests=pending)

@bp.route('/approve/<int:request_id>', methods=['POST'])
@login_required
@role_required('HOD')
def approve(request_id):
    req = FuelRequest.query.get_or_404(request_id)
    if req.status != 'Pending HOD Approval':
        flash('This request is no longer pending.', 'warning')
        return redirect(url_for('hod.dashboard'))
    notes = request.form.get('notes', '')
    req.hod_approval = True
    req.hod_notes = notes
    req.status = 'HOD Approved - Pending Admin'
    db.session.commit()
    send_approval_notification(req, True, notes)
    flash(f'Request #{request_id} approved.', 'success')
    return redirect(url_for('hod.dashboard'))

@bp.route('/decline/<int:request_id>', methods=['POST'])
@login_required
@role_required('HOD')
def decline(request_id):
    req = FuelRequest.query.get_or_404(request_id)
    if req.status != 'Pending HOD Approval':
        flash('This request is no longer pending.', 'warning')
        return redirect(url_for('hod.dashboard'))
    notes = request.form.get('notes', '')
    req.hod_approval = False
    req.hod_notes = notes
    req.status = 'HOD Declined'
    db.session.commit()
    send_approval_notification(req, False, notes)
    flash(f'Request #{request_id} declined.', 'warning')
    return redirect(url_for('hod.dashboard'))
'@

# 13. app/routes/admin.py
Write-FileContent -Path "app/routes/admin.py" -Content @'
from flask import Blueprint, render_template, request, flash, redirect, url_for
from flask_login import login_required, current_user
from app import db
from app.models import FuelRequest
from app.utils.helpers import role_required
from app.utils.notifications import send_approval_notification

bp = Blueprint('admin', __name__, url_prefix='/admin')

@bp.route('/')
@login_required
@role_required('Administrator')
def dashboard():
    pending = FuelRequest.query.filter_by(status='HOD Approved - Pending Admin').all()
    return render_template('admin/dashboard.html', requests=pending)

@bp.route('/approve/<int:request_id>', methods=['POST'])
@login_required
@role_required('Administrator')
def approve(request_id):
    req = FuelRequest.query.get_or_404(request_id)
    if req.status != 'HOD Approved - Pending Admin':
        flash('This request is no longer pending admin approval.', 'warning')
        return redirect(url_for('admin.dashboard'))
    notes = request.form.get('notes', '')
    req.admin_approval = True
    req.admin_notes = notes
    req.status = 'Admin Approved - Pending Issuer'
    db.session.commit()
    send_approval_notification(req, True, notes)
    flash(f'Request #{request_id} approved.', 'success')
    return redirect(url_for('admin.dashboard'))

@bp.route('/decline/<int:request_id>', methods=['POST'])
@login_required
@role_required('Administrator')
def decline(request_id):
    req = FuelRequest.query.get_or_404(request_id)
    if req.status != 'HOD Approved - Pending Admin':
        flash('This request is no longer pending admin approval.', 'warning')
        return redirect(url_for('admin.dashboard'))
    notes = request.form.get('notes', '')
    req.admin_approval = False
    req.admin_notes = notes
    req.status = 'Admin Declined'
    db.session.commit()
    send_approval_notification(req, False, notes)
    flash(f'Request #{request_id} declined.', 'warning')
    return redirect(url_for('admin.dashboard'))
'@

# 14. app/routes/issuer.py
Write-FileContent -Path "app/routes/issuer.py" -Content @'
from flask import Blueprint, render_template, request, flash, redirect, url_for
from flask_login import login_required, current_user
from app import db
from app.models import FuelRequest
from app.utils.helpers import role_required
from app.utils.notifications import send_coupon_notification
from datetime import datetime, timedelta
import secrets

bp = Blueprint('issuer', __name__, url_prefix='/issuer')

@bp.route('/')
@login_required
@role_required('Issuer')
def dashboard():
    pending = FuelRequest.query.filter_by(status='Admin Approved - Pending Issuer').all()
    return render_template('issuer/dashboard.html', requests=pending)

@bp.route('/issue/<int:request_id>', methods=['POST'])
@login_required
@role_required('Issuer')
def issue(request_id):
    req = FuelRequest.query.get_or_404(request_id)
    if req.status != 'Admin Approved - Pending Issuer':
        flash('This request is no longer pending issuer approval.', 'warning')
        return redirect(url_for('issuer.dashboard'))
    coupon_code = f"FVC{request_id:06d}{datetime.now().strftime('%y%m%d')}{secrets.token_hex(2).upper()}"
    req.coupon_code = coupon_code
    req.issuer_approval = True
    req.issuer_notes = request.form.get('notes', '')
    req.issuer_timestamp = datetime.utcnow()
    req.status = 'Coupon Issued'
    db.session.commit()
    coupon_data = {
        'coupon_code': coupon_code,
        'employee_name': req.employee_name,
        'vehicle_number': req.vehicle_number,
        'fuel_type': req.fuel_type,
        'amount': req.amount,
        'expires_at': req.expires_at.strftime('%Y-%m-%d') if req.expires_at else '7 days',
        'email': req.employee.email if req.employee else None,
        'phone': req.employee.phone if req.employee else None
    }
    send_coupon_notification(coupon_data)
    flash(f'Coupon issued: {coupon_code}', 'success')
    return redirect(url_for('issuer.dashboard'))

@bp.route('/decline/<int:request_id>', methods=['POST'])
@login_required
@role_required('Issuer')
def decline(request_id):
    req = FuelRequest.query.get_or_404(request_id)
    if req.status != 'Admin Approved - Pending Issuer':
        flash('This request is no longer pending issuer approval.', 'warning')
        return redirect(url_for('issuer.dashboard'))
    notes = request.form.get('notes', '')
    req.issuer_approval = False
    req.issuer_notes = notes
    req.status = 'Issuer Declined'
    db.session.commit()
    flash(f'Request #{request_id} declined.', 'warning')
    return redirect(url_for('issuer.dashboard'))
'@

# 15. app/routes/attendant.py
Write-FileContent -Path "app/routes/attendant.py" -Content @'
from flask import Blueprint, render_template, request, flash, redirect, url_for
from flask_login import login_required, current_user
from app import db
from app.models import FuelRequest
from app.forms import CouponVerificationForm
from app.utils.helpers import role_required
from datetime import datetime

bp = Blueprint('attendant', __name__, url_prefix='/attendant')

@bp.route('/', methods=['GET', 'POST'])
@login_required
@role_required('Attendant')
def dashboard():
    form = CouponVerificationForm()
    if form.validate_on_submit():
        coupon_code = form.coupon_code.data
        station_name = form.station_name.data
        req = FuelRequest.query.filter_by(coupon_code=coupon_code).first()
        if req:
            if req.status == 'Coupon Issued':
                if req.expires_at and req.expires_at < datetime.utcnow():
                    flash('Coupon has expired.', 'danger')
                else:
                    req.status = 'Coupon Used'
                    req.verified_at = datetime.utcnow()
                    req.verified_by = current_user.name
                    db.session.commit()
                    flash(f'Coupon {coupon_code} verified and redeemed!', 'success')
                    return redirect(url_for('attendant.dashboard'))
            else:
                flash(f'Coupon status is {req.status}. Cannot be used.', 'danger')
        else:
            flash('Invalid coupon code.', 'danger')
    recent = FuelRequest.query.filter(FuelRequest.verified_at.isnot(None)).order_by(FuelRequest.verified_at.desc()).limit(10).all()
    return render_template('attendant/dashboard.html', form=form, recent=recent)
'@

# 16. Templates

# base.html
Write-FileContent -Path "app/templates/base.html" -Content @'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>FuelVault</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="{{ url_for('static', filename='css/custom.css') }}">
</head>
<body>
    <nav class="navbar navbar-expand-lg navbar-dark bg-dark">
        <div class="container">
            <a class="navbar-brand" href="{{ url_for('main.dashboard') }}">FuelVault</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    {% if current_user.is_authenticated %}
                        <li class="nav-item">
                            <span class="nav-link">Welcome, {{ current_user.name }} ({{ current_user.role }})</span>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="{{ url_for('main.notifications') }}">Notifications</a>
                        </li>
                        <li class="nav-item">
                            <a class="nav-link" href="{{ url_for('auth.logout') }}">Logout</a>
                        </li>
                    {% else %}
                        <li class="nav-item">
                            <a class="nav-link" href="{{ url_for('auth.login') }}">Login</a>
                        </li>
                    {% endif %}
                </ul>
            </div>
        </div>
    </nav>

    <div class="container mt-4">
        {% with messages = get_flashed_messages(with_categories=true) %}
            {% if messages %}
                {% for category, message in messages %}
                    <div class="alert alert-{{ category }} alert-dismissible fade show" role="alert">
                        {{ message }}
                        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                    </div>
                {% endfor %}
            {% endif %}
        {% endwith %}

        {% block content %}{% endblock %}
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.1.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
'@

# login.html
Write-FileContent -Path "app/templates/login.html" -Content @'
{% extends "base.html" %}
{% block content %}
<div class="row justify-content-center">
    <div class="col-md-4">
        <div class="card">
            <div class="card-header">Login</div>
            <div class="card-body">
                <form method="POST">
                    {{ form.hidden_tag() }}
                    <div class="mb-3">
                        {{ form.username.label(class="form-label") }}
                        {{ form.username(class="form-control") }}
                    </div>
                    <div class="mb-3">
                        {{ form.password.label(class="form-label") }}
                        {{ form.password(class="form-control") }}
                    </div>
                    <button type="submit" class="btn btn-primary">Login</button>
                </form>
                <hr>
                <p class="text-muted">Demo accounts:<br>
                Employee: user123 / user123<br>
                HOD: hod456 / hod456<br>
                Administrator: admin789 / admin789<br>
                Issuer: issuer000 / issuer000<br>
                Attendant: attendant / attendant123</p>
            </div>
        </div>
    </div>
</div>
{% endblock %}
'@

# notifications.html
Write-FileContent -Path "app/templates/notifications.html" -Content @'
{% extends "base.html" %}
{% block content %}
<h2>Notification History</h2>
<table class="table table-striped">
    <thead>
         <tr>
            <th>Type</th>
            <th>Recipient</th>
            <th>Subject/Message</th>
            <th>Time</th>
            <th>Status</th>
         </tr>
    </thead>
    <tbody>
        {% for n in notifications %}
         <tr>
            <td>{{ n.type|upper }}</td>
            <td>{{ n.to }}</td>
            <td>{{ n.subject if n.subject else n.message[:50] }}</td>
            <td>{{ n.timestamp[:16] }}</td>
            <td>{{ n.status }}</td>
         </tr>
        {% endfor %}
    </tbody>
</table>
{% endblock %}
'@

# employee templates
Write-FileContent -Path "app/templates/employee/dashboard.html" -Content @'
{% extends "base.html" %}
{% block content %}
<div class="row">
    <div class="col-md-4">
        <div class="card mb-4">
            <div class="card-header">Quick Actions</div>
            <div class="card-body">
                <a href="{{ url_for('employee.request_fuel') }}" class="btn btn-primary w-100 mb-2">Request Fuel</a>
                <a href="{{ url_for('employee.my_requests') }}" class="btn btn-secondary w-100 mb-2">My Requests</a>
                <a href="{{ url_for('employee.update_contact') }}" class="btn btn-info w-100">Update Contact Info</a>
            </div>
        </div>
    </div>
    <div class="col-md-8">
        <div class="card">
            <div class="card-header">Welcome, {{ current_user.name }}</div>
            <div class="card-body">
                <p>Department: {{ current_user.department }}</p>
                <p>Email: {{ current_user.email or 'Not set' }}</p>
                <p>Phone: {{ current_user.phone or 'Not set' }}</p>
                <p>Role: {{ current_user.role }}</p>
            </div>
        </div>
    </div>
</div>
{% endblock %}
'@

Write-FileContent -Path "app/templates/employee/request_form.html" -Content @'
{% extends "base.html" %}
{% block content %}
<h2>Request Fuel Coupon</h2>
<form method="POST">
    {{ form.hidden_tag() }}
    <div class="mb-3">
        {{ form.vehicle_number.label(class="form-label") }}
        {{ form.vehicle_number(class="form-control") }}
    </div>
    <div class="mb-3">
        {{ form.vehicle_type.label(class="form-label") }}
        {{ form.vehicle_type(class="form-select") }}
    </div>
    <div class="mb-3">
        {{ form.fuel_type.label(class="form-label") }}
        {{ form.fuel_type(class="form-select") }}
    </div>
    <div class="mb-3">
        {{ form.amount.label(class="form-label") }}
        {{ form.amount(class="form-control") }}
    </div>
    <div class="mb-3">
        {{ form.purpose.label(class="form-label") }}
        {{ form.purpose(class="form-select") }}
    </div>
    <div class="mb-3">
        {{ form.notes.label(class="form-label") }}
        {{ form.notes(class="form-control", rows=3) }}
    </div>
    <button type="submit" class="btn btn-success">Submit Request</button>
    <a href="{{ url_for('employee.dashboard') }}" class="btn btn-secondary">Cancel</a>
</form>
{% endblock %}
'@

Write-FileContent -Path "app/templates/employee/requests.html" -Content @'
{% extends "base.html" %}
{% block content %}
<h2>My Fuel Requests</h2>
<table class="table table-striped">
    <thead>
         <tr>
            <th>ID</th>
            <th>Vehicle</th>
            <th>Fuel</th>
            <th>Amount (L)</th>
            <th>Purpose</th>
            <th>Status</th>
            <th>Date</th>
         </tr>
    </thead>
    <tbody>
        {% for req in requests %}
         <tr>
            <td>{{ req.id }}</td>
            <td>{{ req.vehicle_number }}</td>
            <td>{{ req.fuel_type }}</td>
            <td>{{ req.amount }}</td>
            <td>{{ req.purpose }}</td>
            <td>{{ req.status }}</td>
            <td>{{ req.timestamp.strftime('%Y-%m-%d %H:%M') }}</td>
         </tr>
        {% endfor %}
    </tbody>
</table>
<a href="{{ url_for('employee.dashboard') }}" class="btn btn-secondary">Back</a>
{% endblock %}
'@

Write-FileContent -Path "app/templates/employee/update_contact.html" -Content @'
{% extends "base.html" %}
{% block content %}
<h2>Update Contact Information</h2>
<form method="POST">
    {{ form.hidden_tag() }}
    <div class="mb-3">
        {{ form.email.label(class="form-label") }}
        {{ form.email(class="form-control") }}
    </div>
    <div class="mb-3">
        {{ form.phone.label(class="form-label") }}
        {{ form.phone(class="form-control") }}
    </div>
    <button type="submit" class="btn btn-primary">Update</button>
    <a href="{{ url_for('employee.dashboard') }}" class="btn btn-secondary">Cancel</a>
</form>
{% endblock %}
'@

# hod/dashboard.html
Write-FileContent -Path "app/templates/hod/dashboard.html" -Content @'
{% extends "base.html" %}
{% block content %}
<h2>Pending HOD Approvals</h2>
<table class="table table-bordered">
    <thead>
         <tr>
            <th>ID</th>
            <th>Employee</th>
            <th>Department</th>
            <th>Vehicle</th>
            <th>Fuel</th>
            <th>Amount</th>
            <th>Purpose</th>
            <th>Actions</th>
         </tr>
    </thead>
    <tbody>
        {% for req in requests %}
         <tr>
            <td>{{ req.id }}</td>
            <td>{{ req.employee_name }}</td>
            <td>{{ req.department }}</td>
            <td>{{ req.vehicle_number }}</td>
            <td>{{ req.fuel_type }}</td>
            <td>{{ req.amount }}L</td>
            <td>{{ req.purpose }}</td>
            <td>
                <button class="btn btn-sm btn-success" data-bs-toggle="modal" data-bs-target="#approveModal{{ req.id }}">Approve</button>
                <button class="btn btn-sm btn-danger" data-bs-toggle="modal" data-bs-target="#declineModal{{ req.id }}">Decline</button>
            </td>
         </tr>
        <!-- Approve Modal -->
        <div class="modal fade" id="approveModal{{ req.id }}" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <form method="POST" action="{{ url_for('hod.approve', request_id=req.id) }}">
                        <div class="modal-header">
                            <h5 class="modal-title">Approve Request #{{ req.id }}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-3">
                                <label class="form-label">Notes (optional)</label>
                                <textarea name="notes" class="form-control" rows="3"></textarea>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-success">Approve</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        <!-- Decline Modal -->
        <div class="modal fade" id="declineModal{{ req.id }}" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <form method="POST" action="{{ url_for('hod.decline', request_id=req.id) }}">
                        <div class="modal-header">
                            <h5 class="modal-title">Decline Request #{{ req.id }}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-3">
                                <label class="form-label">Reason (optional)</label>
                                <textarea name="notes" class="form-control" rows="3"></textarea>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-danger">Decline</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        {% endfor %}
    </tbody>
</table>
{% endblock %}
'@

# admin/dashboard.html (similar to hod)
Write-FileContent -Path "app/templates/admin/dashboard.html" -Content @'
{% extends "base.html" %}
{% block content %}
<h2>Pending Admin Approvals</h2>
<table class="table table-bordered">
    <thead>
         <tr>
            <th>ID</th>
            <th>Employee</th>
            <th>Department</th>
            <th>Vehicle</th>
            <th>Fuel</th>
            <th>Amount</th>
            <th>Purpose</th>
            <th>Actions</th>
         </tr>
    </thead>
    <tbody>
        {% for req in requests %}
         <tr>
            <td>{{ req.id }}</td>
            <td>{{ req.employee_name }}</td>
            <td>{{ req.department }}</td>
            <td>{{ req.vehicle_number }}</td>
            <td>{{ req.fuel_type }}</td>
            <td>{{ req.amount }}L</td>
            <td>{{ req.purpose }}</td>
            <td>
                <button class="btn btn-sm btn-success" data-bs-toggle="modal" data-bs-target="#approveModal{{ req.id }}">Approve</button>
                <button class="btn btn-sm btn-danger" data-bs-toggle="modal" data-bs-target="#declineModal{{ req.id }}">Decline</button>
            </td>
         </tr>
        <div class="modal fade" id="approveModal{{ req.id }}" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <form method="POST" action="{{ url_for('admin.approve', request_id=req.id) }}">
                        <div class="modal-header">
                            <h5 class="modal-title">Approve Request #{{ req.id }}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-3">
                                <label class="form-label">Notes (optional)</label>
                                <textarea name="notes" class="form-control" rows="3"></textarea>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-success">Approve</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        <div class="modal fade" id="declineModal{{ req.id }}" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <form method="POST" action="{{ url_for('admin.decline', request_id=req.id) }}">
                        <div class="modal-header">
                            <h5 class="modal-title">Decline Request #{{ req.id }}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-3">
                                <label class="form-label">Reason (optional)</label>
                                <textarea name="notes" class="form-control" rows="3"></textarea>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-danger">Decline</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        {% endfor %}
    </tbody>
</table>
{% endblock %}
'@

# issuer/dashboard.html
Write-FileContent -Path "app/templates/issuer/dashboard.html" -Content @'
{% extends "base.html" %}
{% block content %}
<h2>Pending Issuer Actions</h2>
<table class="table table-bordered">
    <thead>
         <tr>
            <th>ID</th>
            <th>Employee</th>
            <th>Vehicle</th>
            <th>Fuel</th>
            <th>Amount</th>
            <th>Purpose</th>
            <th>Actions</th>
         </tr>
    </thead>
    <tbody>
        {% for req in requests %}
         <tr>
            <td>{{ req.id }}</td>
            <td>{{ req.employee_name }}</td>
            <td>{{ req.vehicle_number }}</td>
            <td>{{ req.fuel_type }}</td>
            <td>{{ req.amount }}L</td>
            <td>{{ req.purpose }}</td>
            <td>
                <button class="btn btn-sm btn-success" data-bs-toggle="modal" data-bs-target="#issueModal{{ req.id }}">Issue Coupon</button>
                <button class="btn btn-sm btn-danger" data-bs-toggle="modal" data-bs-target="#declineModal{{ req.id }}">Decline</button>
            </td>
         </tr>
        <div class="modal fade" id="issueModal{{ req.id }}" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <form method="POST" action="{{ url_for('issuer.issue', request_id=req.id) }}">
                        <div class="modal-header">
                            <h5 class="modal-title">Issue Coupon for #{{ req.id }}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-3">
                                <label class="form-label">Notes (optional)</label>
                                <textarea name="notes" class="form-control" rows="3"></textarea>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-success">Issue</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        <div class="modal fade" id="declineModal{{ req.id }}" tabindex="-1">
            <div class="modal-dialog">
                <div class="modal-content">
                    <form method="POST" action="{{ url_for('issuer.decline', request_id=req.id) }}">
                        <div class="modal-header">
                            <h5 class="modal-title">Decline Request #{{ req.id }}</h5>
                            <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                        </div>
                        <div class="modal-body">
                            <div class="mb-3">
                                <label class="form-label">Reason (optional)</label>
                                <textarea name="notes" class="form-control" rows="3"></textarea>
                            </div>
                        </div>
                        <div class="modal-footer">
                            <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Cancel</button>
                            <button type="submit" class="btn btn-danger">Decline</button>
                        </div>
                    </form>
                </div>
            </div>
        </div>
        {% endfor %}
    </tbody>
</table>
{% endblock %}
'@

# attendant/dashboard.html
Write-FileContent -Path "app/templates/attendant/dashboard.html" -Content @'
{% extends "base.html" %}
{% block content %}
<h2>Coupon Verification</h2>
<div class="row">
    <div class="col-md-6">
        <div class="card">
            <div class="card-header">Verify Coupon</div>
            <div class="card-body">
                <form method="POST">
                    {{ form.hidden_tag() }}
                    <div class="mb-3">
                        {{ form.coupon_code.label(class="form-label") }}
                        {{ form.coupon_code(class="form-control") }}
                    </div>
                    <div class="mb-3">
                        {{ form.station_name.label(class="form-label") }}
                        {{ form.station_name(class="form-control") }}
                    </div>
                    <button type="submit" class="btn btn-primary">Verify & Redeem</button>
                </form>
            </div>
        </div>
    </div>
    <div class="col-md-6">
        <div class="card">
            <div class="card-header">Recent Verifications</div>
            <div class="card-body">
                <table class="table table-sm">
                    <thead>
                         <tr>
                            <th>Coupon</th>
                            <th>Vehicle</th>
                            <th>Verified By</th>
                            <th>Time</th>
                         </tr>
                    </thead>
                    <tbody>
                        {% for req in recent %}
                         <tr>
                            <td>{{ req.coupon_code }}</td>
                            <td>{{ req.vehicle_number }}</td>
                            <td>{{ req.verified_by }}</td>
                            <td>{{ req.verified_at.strftime('%Y-%m-%d %H:%M') if req.verified_at else '' }}</td>
                         </tr>
                        {% endfor %}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</div>
{% endblock %}
'@

# static/css/custom.css
Write-FileContent -Path "app/static/css/custom.css" -Content @'
body {
    background-color: #f8f9fa;
}
.navbar-brand {
    font-weight: bold;
}
.card-header {
    background-color: #e9ecef;
}
'@

# run.py
Write-FileContent -Path "run.py" -Content @'
from app import create_app

app = create_app()

if __name__ == '__main__':
    app.run(debug=True)
'@

# create_db.py
Write-FileContent -Path "create_db.py" -Content @'
from app import create_app, db
from app.models import User
from werkzeug.security import generate_password_hash
from datetime import datetime

app = create_app()
with app.app_context():
    db.create_all()
    if not User.query.first():
        default_users = [
            ("user123", "user123", "Employee", "John Employee", "IT", "john@example.com", "+1234567890"),
            ("hod456", "hod456", "HOD", "Dr. Smith HOD", "IT", "hod@example.com", "+1234567891"),
            ("admin789", "admin789", "Administrator", "Admin User", "Administration", "admin@example.com", "+1234567892"),
            ("issuer000", "issuer000", "Issuer", "Fuel Issuer", "Fuel Station", "issuer@example.com", "+1234567893"),
            ("attendant", "attendant123", "Attendant", "Fuel Attendant", "Main Station", "attendant@example.com", "+1234567894")
        ]
        for username, password, role, name, dept, email, phone in default_users:
            user = User(
                username=username,
                password_hash=generate_password_hash(password),
                role=role,
                name=name,
                department=dept,
                email=email,
                phone=phone,
                is_active=True
            )
            db.session.add(user)
        db.session.commit()
        print("Default users created.")
    else:
        print("Database already initialized.")
'@

# requirements.txt
Write-FileContent -Path "requirements.txt" -Content @'
Flask==2.2.2
Flask-SQLAlchemy==3.0.2
Flask-Login==0.6.2
Flask-WTF==1.1.1
Werkzeug==2.2.2
WTForms==3.0.1
'@

# README.md
Write-FileContent -Path "README.md" -Content @'
# FuelVault Web App

A fuel coupon management system built with Flask. It supports multiple user roles (Employee, HOD, Administrator, Issuer, Attendant) and a multi-stage approval workflow. Notifications are simulated via email/SMS.

## Features

- User login with role-based access control
- Employees can request fuel coupons
- HOD approves/declines requests
- Administrator approves/declines
- Issuer generates unique coupon codes and notifies employees
- Attendant verifies and redeems coupons
- Notification history

## Installation

1. Clone the repository
2. Create a virtual environment: `python -m venv venv`
3. Activate it: `venv\Scripts\activate` (Windows) or `source venv/bin/activate` (Linux/Mac)
4. Install dependencies: `pip install -r requirements.txt`
5. Create the database: `python create_db.py`
6. Run the app: `python run.py`
7. Visit `http://127.0.0.1:5000` and log in with one of the default accounts:

   - Employee: user123 / user123
   - HOD: hod456 / hod456
   - Administrator: admin789 / admin789
   - Issuer: issuer000 / issuer000
   - Attendant: attendant / attendant123

## Project Structure
