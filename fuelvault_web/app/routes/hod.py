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
