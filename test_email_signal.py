import os
import smtplib
import ssl
from email.mime.text import MIMEText
from datetime import datetime, timezone

# Load .env
env_path = os.path.join(os.path.dirname(__file__), ".env")
if os.path.isfile(env_path):
    with open(env_path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                os.environ.setdefault(k.strip(), v.strip().strip('"').strip("'"))

smtp_host = os.environ.get("SIGNAL_SMTP_HOST", "smtp.gmail.com")
smtp_port = int(os.environ.get("SIGNAL_SMTP_PORT", "465"))
sender = os.environ.get("SIGNAL_EMAIL_SENDER", "")
password = os.environ.get("SIGNAL_EMAIL_PASSWORD", "")
recipient = os.environ.get("SIGNAL_EMAIL_RECIPIENT", "")

print("=" * 60)
print("DERIV EDGE RADAR — EMAIL SIGNAL TEST")
print("=" * 60)
print(f"SMTP Host:      {smtp_host}:{smtp_port}")
print(f"Sender:         {sender}")
print(f"Recipient:      {recipient}")
print(f"Password set:   {'Yes' if bool(password) else 'NO'}")

if not all([smtp_host, sender, password, recipient]):
    print("ERROR: Missing email configuration in .env!")
    exit(1)

now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")

subject = "🟢 [TEST] BUY Signal — R_25 (Hammer Reversal @ Support)"
body = f"""==================================================
🟢 DERIV EDGE RADAR — LIVE TEST TRADE SIGNAL
==================================================

Symbol:     Volatility 25 Index (R_25)
Action:     BUY
Pattern:    Hammer Reversal at Key Support
HTF Trend:  BULLISH (1H Structure Confirmation)

--------------------------------------------------
TRADE EXECUTION PARAMETERS:
--------------------------------------------------
Entry Price:  2744.5000
Stop Loss:    2737.2000  (Risk: 7.30 pts)
Take Profit:  2759.1000  (Reward: 14.60 pts)
Risk:Reward:  1:2.00
Win Rate Est: ~70.0%

Recommended Lot: 0.50 (Deriv Min Lot for R_25)
Time (UTC):   {now_str}
Radar Status: Active & Monitoring

==================================================
This is an automated test from your Deriv Trading Bot pipeline.
==================================================
"""

msg = MIMEText(body, "plain", "utf-8")
msg["Subject"] = subject
msg["From"] = f"Deriv Edge Radar <{sender}>"
msg["To"] = recipient

print("\nConnecting to Gmail SMTP server...")
try:
    ctx = ssl.create_default_context()
    if smtp_port == 587:
        with smtplib.SMTP(smtp_host, smtp_port, timeout=15) as server:
            server.ehlo()
            server.starttls(context=ctx)
            server.login(sender, password)
            server.sendmail(sender, recipient, msg.as_string())
    else:
        with smtplib.SMTP_SSL(smtp_host, smtp_port, context=ctx, timeout=15) as server:
            server.login(sender, password)
            server.sendmail(sender, recipient, msg.as_string())
    
    print("SUCCESS: Test email signal was sent successfully (SMTP 250 OK)!")
    print(f"Delivered to: {recipient}")
except Exception as e:
    print(f"FAILED to send email: {e}")
    exit(1)
