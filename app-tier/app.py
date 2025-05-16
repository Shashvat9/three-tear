from flask import Flask
import os

app = Flask(__name__)

# Example: Get DB host from environment variable or SSM Parameter Store
# DB_HOST = os.environ.get('DB_HOST', 'db.example.com') # This would be set by Terraform/SSM

@app.route('/')
def hello_app_tier():
    return "Hello from the App Tier!"

@app.route('/app')
def app_data():
    # In a real app, you'd connect to RDS here using DB_HOST
    return "Data from App Tier (potentially from database)"

@app.route('/health')
def health_check():
    return "OK", 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)