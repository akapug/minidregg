"""Run the unmodified upstream Flask app with the production-mode werkzeug server.

Upstream's run.py enables Flask debug mode (an interactive debugger) and binds
127.0.0.1:5000; inside the grain the bridge reaches us on 5000 over loopback."""
from app import app, db

with app.app_context():
    db.create_all()
app.run(debug=False, host="127.0.0.1", port=5000, threaded=True)
