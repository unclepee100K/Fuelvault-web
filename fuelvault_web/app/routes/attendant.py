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
