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
