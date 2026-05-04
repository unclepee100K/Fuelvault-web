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
