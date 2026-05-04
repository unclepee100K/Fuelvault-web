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
