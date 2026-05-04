from flask import Flask
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager
from config import Config
from flask_mail import Mail

mail = Mail()

def create_app(config_class=Config):
    app = Flask(__name__)
    # ... existing code ...
    mail.init_app(app)
    # ... rest ...
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

    # User loader for Flask-Login
    @login_manager.user_loader
    def load_user(user_id):
        from app.models import User
        return User.query.get(user_id)

    return app