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
