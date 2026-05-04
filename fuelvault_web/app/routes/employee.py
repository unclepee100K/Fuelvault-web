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
