from flask import Flask, request, jsonify, send_file
import os
import boto3
from botocore.exceptions import ClientError
import io
import uuid
from datetime import datetime

app = Flask(__name__)

# Configuration from environment variables
S3_BUCKET_NAME = os.environ.get('S3_BUCKET_NAME', 'default-bucket')
AWS_REGION = os.environ.get('AWS_REGION', 'us-east-1')
DB_HOST = os.environ.get('DB_HOST', 'localhost')
DB_NAME = os.environ.get('DB_NAME', 'drivedb')

# Initialize S3 client
s3_client = boto3.client('s3', region_name=AWS_REGION)


@app.route('/')
def hello_app_tier():
    return jsonify({
        "message": "Welcome to the Google Drive Clone API",
        "version": "1.0.0",
        "endpoints": {
            "upload": "POST /files/upload",
            "download": "GET /files/download/<file_id>",
            "list": "GET /files",
            "delete": "DELETE /files/<file_id>",
            "info": "GET /files/<file_id>/info"
        }
    })


@app.route('/health')
def health_check():
    return "OK", 200


@app.route('/files', methods=['GET'])
def list_files():
    """List all files in the user's storage"""
    try:
        prefix = request.args.get('prefix', '')
        
        response = s3_client.list_objects_v2(
            Bucket=S3_BUCKET_NAME,
            Prefix=prefix,
            MaxKeys=100
        )
        
        files = []
        if 'Contents' in response:
            for obj in response['Contents']:
                files.append({
                    'file_id': obj['Key'],
                    'name': obj['Key'].split('/')[-1],
                    'size': obj['Size'],
                    'last_modified': obj['LastModified'].isoformat(),
                    'storage_class': obj.get('StorageClass', 'STANDARD')
                })
        
        return jsonify({
            'success': True,
            'files': files,
            'count': len(files)
        })
    except ClientError as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/files/upload', methods=['POST'])
def upload_file():
    """Upload a file to S3 storage"""
    try:
        if 'file' not in request.files:
            return jsonify({
                'success': False,
                'error': 'No file provided'
            }), 400
        
        file = request.files['file']
        if file.filename == '':
            return jsonify({
                'success': False,
                'error': 'No file selected'
            }), 400
        
        # Generate unique file ID
        file_id = str(uuid.uuid4())
        folder = request.form.get('folder', '')
        
        # Create S3 key (path)
        if folder:
            s3_key = f"{folder}/{file_id}_{file.filename}"
        else:
            s3_key = f"{file_id}_{file.filename}"
        
        # Upload to S3
        s3_client.upload_fileobj(
            file,
            S3_BUCKET_NAME,
            s3_key,
            ExtraArgs={
                'ContentType': file.content_type or 'application/octet-stream',
                'Metadata': {
                    'original_filename': file.filename,
                    'upload_timestamp': datetime.utcnow().isoformat()
                }
            }
        )
        
        return jsonify({
            'success': True,
            'file_id': s3_key,
            'filename': file.filename,
            'message': 'File uploaded successfully'
        }), 201
        
    except ClientError as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/files/download/<path:file_id>', methods=['GET'])
def download_file(file_id):
    """Download a file from S3 storage"""
    try:
        # Get file from S3
        response = s3_client.get_object(Bucket=S3_BUCKET_NAME, Key=file_id)
        
        # Get original filename from metadata or extract from key
        metadata = response.get('Metadata', {})
        original_filename = metadata.get('original_filename', file_id.split('_', 1)[-1])
        
        # Create file-like object
        file_stream = io.BytesIO(response['Body'].read())
        
        return send_file(
            file_stream,
            as_attachment=True,
            download_name=original_filename,
            mimetype=response['ContentType']
        )
        
    except ClientError as e:
        if e.response['Error']['Code'] == 'NoSuchKey':
            return jsonify({
                'success': False,
                'error': 'File not found'
            }), 404
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/files/<path:file_id>', methods=['DELETE'])
def delete_file(file_id):
    """Delete a file from S3 storage"""
    try:
        s3_client.delete_object(Bucket=S3_BUCKET_NAME, Key=file_id)
        
        return jsonify({
            'success': True,
            'message': 'File deleted successfully',
            'file_id': file_id
        })
        
    except ClientError as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/files/<path:file_id>/info', methods=['GET'])
def get_file_info(file_id):
    """Get metadata about a specific file"""
    try:
        response = s3_client.head_object(Bucket=S3_BUCKET_NAME, Key=file_id)
        
        return jsonify({
            'success': True,
            'file_info': {
                'file_id': file_id,
                'size': response['ContentLength'],
                'content_type': response['ContentType'],
                'last_modified': response['LastModified'].isoformat(),
                'metadata': response.get('Metadata', {}),
                'version_id': response.get('VersionId'),
                'storage_class': response.get('StorageClass', 'STANDARD')
            }
        })
        
    except ClientError as e:
        if e.response['Error']['Code'] == '404':
            return jsonify({
                'success': False,
                'error': 'File not found'
            }), 404
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/files/<path:file_id>/presigned', methods=['GET'])
def get_presigned_url(file_id):
    """Generate a presigned URL for direct download"""
    try:
        expiration = int(request.args.get('expires', 3600))  # Default 1 hour
        
        url = s3_client.generate_presigned_url(
            'get_object',
            Params={'Bucket': S3_BUCKET_NAME, 'Key': file_id},
            ExpiresIn=expiration
        )
        
        return jsonify({
            'success': True,
            'presigned_url': url,
            'expires_in': expiration
        })
        
    except ClientError as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


@app.route('/storage/stats', methods=['GET'])
def get_storage_stats():
    """Get storage statistics"""
    try:
        paginator = s3_client.get_paginator('list_objects_v2')
        
        total_size = 0
        total_files = 0
        
        for page in paginator.paginate(Bucket=S3_BUCKET_NAME):
            if 'Contents' in page:
                for obj in page['Contents']:
                    total_size += obj['Size']
                    total_files += 1
        
        return jsonify({
            'success': True,
            'stats': {
                'total_files': total_files,
                'total_size_bytes': total_size,
                'total_size_mb': round(total_size / (1024 * 1024), 2),
                'bucket_name': S3_BUCKET_NAME
            }
        })
        
    except ClientError as e:
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)