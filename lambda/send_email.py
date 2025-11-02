import boto3
import os
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from email.mime.text import MIMEText

s3 = boto3.client('s3')
ses = boto3.client('ses')

SENDER = os.environ['SENDER_EMAIL']
RECIPIENTS = os.environ['RECIPIENT_EMAILS'].split(',')

def lambda_handler(event, context):
    print("Event:", event)
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        print(f"New file: s3://{bucket}/{key}")

        # Download file from S3
        tmp_file = f"/tmp/{os.path.basename(key)}"
        s3.download_file(bucket, key, tmp_file)

        # Compose Email
        msg = MIMEMultipart()
        msg['Subject'] = f"New S3 Asset Uploaded: {key}"
        msg['From'] = SENDER
        msg['To'] = ", ".join(RECIPIENTS)

        body = MIMEText(f"A new file has been uploaded to {bucket}: {key}")
        msg.attach(body)

        with open(tmp_file, "rb") as f:
            part = MIMEApplication(f.read())
            part.add_header('Content-Disposition', 'attachment', filename=os.path.basename(key))
            msg.attach(part)

        # Send Email via SES
        ses.send_raw_email(
            Source=SENDER,
            Destinations=RECIPIENTS,
            RawMessage={'Data': msg.as_string()}
        )

    return {"status": "Email sent successfully"}
