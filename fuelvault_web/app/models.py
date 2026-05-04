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
