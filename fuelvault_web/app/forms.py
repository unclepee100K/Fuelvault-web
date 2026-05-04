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
