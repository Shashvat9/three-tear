const express = require('express');
const path = require('path');
const multer = require('multer');
const axios = require('axios');
const FormData = require('form-data');

const app = express();
const port = 3000;

// Configure multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({ 
  storage: storage,
  limits: { fileSize: 100 * 1024 * 1024 } // 100MB limit
});

// App tier URL from environment or default
const APP_TIER_URL = process.env.APP_TIER_URL || 'http://localhost:5000';

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Serve static files
app.use(express.static('public'));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

// Main page - Google Drive Clone UI
app.get('/', (req, res) => {
  res.send(`
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My Drive - Cloud Storage</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css" rel="stylesheet">
    <style>
        :root {
            --primary-color: #1a73e8;
            --secondary-color: #5f6368;
            --background-color: #f8f9fa;
            --card-background: #ffffff;
            --hover-color: #e8f0fe;
        }
        
        body {
            background-color: var(--background-color);
            font-family: 'Google Sans', 'Segoe UI', Roboto, sans-serif;
        }
        
        .sidebar {
            background-color: var(--card-background);
            height: 100vh;
            padding-top: 20px;
            border-right: 1px solid #dadce0;
            position: fixed;
            width: 256px;
        }
        
        .main-content {
            margin-left: 256px;
            padding: 20px 30px;
        }
        
        .logo {
            font-size: 22px;
            font-weight: 500;
            color: var(--secondary-color);
            padding: 10px 24px 20px;
        }
        
        .logo i {
            color: var(--primary-color);
            margin-right: 8px;
        }
        
        .upload-btn {
            background-color: var(--card-background);
            border: none;
            border-radius: 24px;
            padding: 12px 24px;
            margin: 16px 24px;
            font-size: 14px;
            font-weight: 500;
            box-shadow: 0 1px 3px rgba(0,0,0,0.12), 0 1px 2px rgba(0,0,0,0.24);
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 12px;
            transition: box-shadow 0.3s ease;
        }
        
        .upload-btn:hover {
            box-shadow: 0 3px 6px rgba(0,0,0,0.16), 0 3px 6px rgba(0,0,0,0.23);
        }
        
        .upload-btn i {
            font-size: 20px;
            color: var(--primary-color);
        }
        
        .nav-item {
            padding: 8px 24px;
            display: flex;
            align-items: center;
            gap: 16px;
            color: var(--secondary-color);
            text-decoration: none;
            font-size: 14px;
            cursor: pointer;
            border-radius: 0 24px 24px 0;
            margin-right: 12px;
        }
        
        .nav-item:hover, .nav-item.active {
            background-color: var(--hover-color);
            color: var(--primary-color);
        }
        
        .nav-item i {
            font-size: 20px;
        }
        
        .file-list {
            background-color: var(--card-background);
            border-radius: 8px;
            box-shadow: 0 1px 2px rgba(0,0,0,0.1);
        }
        
        .file-item {
            display: flex;
            align-items: center;
            padding: 12px 16px;
            border-bottom: 1px solid #e0e0e0;
            cursor: pointer;
            transition: background-color 0.2s;
        }
        
        .file-item:hover {
            background-color: var(--hover-color);
        }
        
        .file-item:last-child {
            border-bottom: none;
        }
        
        .file-icon {
            font-size: 24px;
            margin-right: 16px;
            color: var(--secondary-color);
        }
        
        .file-icon.folder { color: #5f6368; }
        .file-icon.image { color: #d93025; }
        .file-icon.document { color: #4285f4; }
        .file-icon.spreadsheet { color: #0f9d58; }
        .file-icon.pdf { color: #ea4335; }
        .file-icon.video { color: #ff0000; }
        .file-icon.audio { color: #ff6d00; }
        .file-icon.archive { color: #9c27b0; }
        
        .file-info {
            flex: 1;
        }
        
        .file-name {
            font-size: 14px;
            color: #202124;
            margin-bottom: 2px;
        }
        
        .file-meta {
            font-size: 12px;
            color: var(--secondary-color);
        }
        
        .file-actions {
            display: flex;
            gap: 8px;
        }
        
        .file-actions button {
            border: none;
            background: none;
            padding: 8px;
            border-radius: 50%;
            cursor: pointer;
            color: var(--secondary-color);
        }
        
        .file-actions button:hover {
            background-color: #e8e8e8;
        }
        
        .storage-info {
            padding: 20px 24px;
            border-top: 1px solid #dadce0;
            position: absolute;
            bottom: 20px;
            width: 100%;
        }
        
        .storage-bar {
            height: 4px;
            background-color: #e0e0e0;
            border-radius: 2px;
            margin: 8px 0;
        }
        
        .storage-used {
            height: 100%;
            background-color: var(--primary-color);
            border-radius: 2px;
        }
        
        .header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 24px;
        }
        
        .header h1 {
            font-size: 24px;
            font-weight: 400;
            color: #202124;
        }
        
        .search-bar {
            background-color: #f1f3f4;
            border: none;
            border-radius: 8px;
            padding: 12px 48px;
            width: 400px;
            font-size: 14px;
        }
        
        .search-bar:focus {
            background-color: var(--card-background);
            box-shadow: 0 1px 3px rgba(0,0,0,0.12);
            outline: none;
        }
        
        .drop-zone {
            border: 2px dashed #dadce0;
            border-radius: 8px;
            padding: 40px;
            text-align: center;
            margin-bottom: 24px;
            transition: all 0.3s ease;
            background-color: var(--card-background);
        }
        
        .drop-zone.dragover {
            border-color: var(--primary-color);
            background-color: var(--hover-color);
        }
        
        .drop-zone i {
            font-size: 48px;
            color: var(--primary-color);
            margin-bottom: 16px;
        }
        
        .empty-state {
            text-align: center;
            padding: 60px;
            color: var(--secondary-color);
        }
        
        .empty-state i {
            font-size: 80px;
            margin-bottom: 20px;
        }
        
        .toast-container {
            position: fixed;
            bottom: 20px;
            right: 20px;
            z-index: 1000;
        }
        
        .loading-spinner {
            display: none;
            text-align: center;
            padding: 20px;
        }
        
        @media (max-width: 768px) {
            .sidebar {
                display: none;
            }
            .main-content {
                margin-left: 0;
            }
        }
    </style>
</head>
<body>
    <!-- Sidebar -->
    <div class="sidebar">
        <div class="logo">
            <i class="bi bi-cloud-fill"></i> My Drive
        </div>
        
        <label class="upload-btn" for="fileInput">
            <i class="bi bi-plus-lg"></i>
            <span>New</span>
        </label>
        <input type="file" id="fileInput" style="display: none;" multiple>
        
        <nav class="mt-3">
            <a href="#" class="nav-item active">
                <i class="bi bi-folder-fill"></i>
                <span>My Drive</span>
            </a>
            <a href="#" class="nav-item">
                <i class="bi bi-laptop"></i>
                <span>Computers</span>
            </a>
            <a href="#" class="nav-item">
                <i class="bi bi-people-fill"></i>
                <span>Shared with me</span>
            </a>
            <a href="#" class="nav-item">
                <i class="bi bi-clock-history"></i>
                <span>Recent</span>
            </a>
            <a href="#" class="nav-item">
                <i class="bi bi-star-fill"></i>
                <span>Starred</span>
            </a>
            <a href="#" class="nav-item">
                <i class="bi bi-trash-fill"></i>
                <span>Trash</span>
            </a>
        </nav>
        
        <div class="storage-info">
            <small class="text-muted">Storage</small>
            <div class="storage-bar">
                <div class="storage-used" id="storageBar" style="width: 0%"></div>
            </div>
            <small class="text-muted" id="storageText">Loading...</small>
        </div>
    </div>
    
    <!-- Main Content -->
    <div class="main-content">
        <div class="header">
            <h1>My Drive</h1>
            <div class="d-flex gap-3">
                <input type="text" class="search-bar" placeholder="Search in Drive" id="searchInput">
                <button class="btn btn-outline-secondary" onclick="refreshFiles()">
                    <i class="bi bi-arrow-clockwise"></i>
                </button>
            </div>
        </div>
        
        <!-- Drop Zone -->
        <div class="drop-zone" id="dropZone">
            <i class="bi bi-cloud-arrow-up"></i>
            <h5>Drop files here to upload</h5>
            <p class="text-muted">or click "New" to select files</p>
        </div>
        
        <!-- Loading Spinner -->
        <div class="loading-spinner" id="loadingSpinner">
            <div class="spinner-border text-primary" role="status">
                <span class="visually-hidden">Loading...</span>
            </div>
            <p class="mt-2">Loading files...</p>
        </div>
        
        <!-- File List -->
        <div class="file-list" id="fileList">
            <!-- Files will be loaded here -->
        </div>
        
        <!-- Empty State -->
        <div class="empty-state" id="emptyState" style="display: none;">
            <i class="bi bi-folder2-open"></i>
            <h4>No files yet</h4>
            <p>Upload files to get started</p>
        </div>
    </div>
    
    <!-- Toast Container -->
    <div class="toast-container" id="toastContainer"></div>
    
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script>
        const API_BASE = '/api';
        
        // File type icons mapping
        const fileIcons = {
            'folder': 'bi-folder-fill folder',
            'image': 'bi-file-image image',
            'pdf': 'bi-file-pdf pdf',
            'document': 'bi-file-word document',
            'spreadsheet': 'bi-file-excel spreadsheet',
            'video': 'bi-file-play video',
            'audio': 'bi-file-music audio',
            'archive': 'bi-file-zip archive',
            'default': 'bi-file-earmark'
        };
        
        function getFileIcon(filename) {
            const ext = filename.split('.').pop().toLowerCase();
            const imageExts = ['jpg', 'jpeg', 'png', 'gif', 'bmp', 'svg', 'webp'];
            const docExts = ['doc', 'docx', 'txt', 'rtf'];
            const spreadsheetExts = ['xls', 'xlsx', 'csv'];
            const videoExts = ['mp4', 'avi', 'mov', 'wmv', 'mkv'];
            const audioExts = ['mp3', 'wav', 'ogg', 'flac'];
            const archiveExts = ['zip', 'rar', '7z', 'tar', 'gz'];
            
            if (imageExts.includes(ext)) return fileIcons.image;
            if (ext === 'pdf') return fileIcons.pdf;
            if (docExts.includes(ext)) return fileIcons.document;
            if (spreadsheetExts.includes(ext)) return fileIcons.spreadsheet;
            if (videoExts.includes(ext)) return fileIcons.video;
            if (audioExts.includes(ext)) return fileIcons.audio;
            if (archiveExts.includes(ext)) return fileIcons.archive;
            return fileIcons.default;
        }
        
        function formatFileSize(bytes) {
            if (bytes === 0) return '0 Bytes';
            const k = 1024;
            const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
            const i = Math.floor(Math.log(bytes) / Math.log(k));
            return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
        }
        
        function formatDate(dateString) {
            const date = new Date(dateString);
            const now = new Date();
            const diff = now - date;
            const days = Math.floor(diff / (1000 * 60 * 60 * 24));
            
            if (days === 0) return 'Today';
            if (days === 1) return 'Yesterday';
            if (days < 7) return date.toLocaleDateString('en-US', { weekday: 'long' });
            return date.toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
        }
        
        function showToast(message, type = 'success') {
            const toast = document.createElement('div');
            toast.className = 'toast show';
            toast.setAttribute('role', 'alert');
            toast.innerHTML = \`
                <div class="toast-header bg-\${type === 'success' ? 'success' : 'danger'} text-white">
                    <strong class="me-auto">\${type === 'success' ? 'Success' : 'Error'}</strong>
                    <button type="button" class="btn-close btn-close-white" data-bs-dismiss="toast"></button>
                </div>
                <div class="toast-body">\${message}</div>
            \`;
            document.getElementById('toastContainer').appendChild(toast);
            setTimeout(() => toast.remove(), 5000);
        }
        
        async function loadFiles() {
            const fileList = document.getElementById('fileList');
            const loadingSpinner = document.getElementById('loadingSpinner');
            const emptyState = document.getElementById('emptyState');
            
            loadingSpinner.style.display = 'block';
            fileList.innerHTML = '';
            emptyState.style.display = 'none';
            
            try {
                const response = await fetch(API_BASE + '/files');
                const data = await response.json();
                
                loadingSpinner.style.display = 'none';
                
                if (data.success && data.files.length > 0) {
                    data.files.forEach(file => {
                        const iconClass = getFileIcon(file.name);
                        const fileItem = document.createElement('div');
                        fileItem.className = 'file-item';
                        fileItem.innerHTML = \`
                            <i class="bi \${iconClass} file-icon"></i>
                            <div class="file-info">
                                <div class="file-name">\${file.name}</div>
                                <div class="file-meta">\${formatFileSize(file.size)} • \${formatDate(file.last_modified)}</div>
                            </div>
                            <div class="file-actions">
                                <button onclick="downloadFile('\${file.file_id}')" title="Download">
                                    <i class="bi bi-download"></i>
                                </button>
                                <button onclick="deleteFile('\${file.file_id}')" title="Delete">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </div>
                        \`;
                        fileList.appendChild(fileItem);
                    });
                } else {
                    emptyState.style.display = 'block';
                }
            } catch (error) {
                loadingSpinner.style.display = 'none';
                showToast('Failed to load files: ' + error.message, 'error');
            }
        }
        
        async function uploadFiles(files) {
            for (const file of files) {
                const formData = new FormData();
                formData.append('file', file);
                
                try {
                    showToast('Uploading ' + file.name + '...');
                    const response = await fetch(API_BASE + '/files/upload', {
                        method: 'POST',
                        body: formData
                    });
                    const data = await response.json();
                    
                    if (data.success) {
                        showToast(file.name + ' uploaded successfully!');
                    } else {
                        showToast('Failed to upload ' + file.name, 'error');
                    }
                } catch (error) {
                    showToast('Failed to upload ' + file.name + ': ' + error.message, 'error');
                }
            }
            loadFiles();
            loadStorageStats();
        }
        
        async function downloadFile(fileId) {
            window.location.href = API_BASE + '/files/download/' + encodeURIComponent(fileId);
        }
        
        async function deleteFile(fileId) {
            if (!confirm('Are you sure you want to delete this file?')) return;
            
            try {
                const response = await fetch(API_BASE + '/files/' + encodeURIComponent(fileId), {
                    method: 'DELETE'
                });
                const data = await response.json();
                
                if (data.success) {
                    showToast('File deleted successfully!');
                    loadFiles();
                    loadStorageStats();
                } else {
                    showToast('Failed to delete file', 'error');
                }
            } catch (error) {
                showToast('Failed to delete file: ' + error.message, 'error');
            }
        }
        
        async function loadStorageStats() {
            try {
                const response = await fetch(API_BASE + '/storage/stats');
                const data = await response.json();
                
                if (data.success) {
                    const usedMB = data.stats.total_size_mb;
                    const maxGB = 15; // Simulated max storage
                    const usedPercent = Math.min((usedMB / (maxGB * 1024)) * 100, 100);
                    
                    document.getElementById('storageBar').style.width = usedPercent + '%';
                    document.getElementById('storageText').textContent = 
                        usedMB.toFixed(2) + ' MB of ' + maxGB + ' GB used';
                }
            } catch (error) {
                document.getElementById('storageText').textContent = 'Unable to load storage info';
            }
        }
        
        function refreshFiles() {
            loadFiles();
            loadStorageStats();
        }
        
        // Event Listeners
        document.getElementById('fileInput').addEventListener('change', (e) => {
            if (e.target.files.length > 0) {
                uploadFiles(e.target.files);
            }
        });
        
        // Drag and Drop
        const dropZone = document.getElementById('dropZone');
        
        dropZone.addEventListener('dragover', (e) => {
            e.preventDefault();
            dropZone.classList.add('dragover');
        });
        
        dropZone.addEventListener('dragleave', () => {
            dropZone.classList.remove('dragover');
        });
        
        dropZone.addEventListener('drop', (e) => {
            e.preventDefault();
            dropZone.classList.remove('dragover');
            if (e.dataTransfer.files.length > 0) {
                uploadFiles(e.dataTransfer.files);
            }
        });
        
        // Search
        document.getElementById('searchInput').addEventListener('input', (e) => {
            const query = e.target.value.toLowerCase();
            const items = document.querySelectorAll('.file-item');
            items.forEach(item => {
                const name = item.querySelector('.file-name').textContent.toLowerCase();
                item.style.display = name.includes(query) ? 'flex' : 'none';
            });
        });
        
        // Initial load
        loadFiles();
        loadStorageStats();
    </script>
</body>
</html>
  `);
});

// API Proxy endpoints - these forward requests to the App Tier
app.get('/api/files', async (req, res) => {
  try {
    const response = await axios.get(`${APP_TIER_URL}/files`, {
      params: req.query
    });
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

app.post('/api/files/upload', upload.single('file'), async (req, res) => {
  try {
    const formData = new FormData();
    formData.append('file', req.file.buffer, {
      filename: req.file.originalname,
      contentType: req.file.mimetype
    });
    
    if (req.body.folder) {
      formData.append('folder', req.body.folder);
    }
    
    const response = await axios.post(`${APP_TIER_URL}/files/upload`, formData, {
      headers: formData.getHeaders(),
      maxContentLength: Infinity,
      maxBodyLength: Infinity
    });
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

app.get('/api/files/download/:fileId(*)', async (req, res) => {
  try {
    const response = await axios.get(`${APP_TIER_URL}/files/download/${req.params.fileId}`, {
      responseType: 'stream'
    });
    
    // Forward headers
    res.set(response.headers);
    response.data.pipe(res);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

app.delete('/api/files/:fileId(*)', async (req, res) => {
  try {
    const response = await axios.delete(`${APP_TIER_URL}/files/${req.params.fileId}`);
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

app.get('/api/files/:fileId(*)/info', async (req, res) => {
  try {
    const response = await axios.get(`${APP_TIER_URL}/files/${req.params.fileId}/info`);
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

app.get('/api/storage/stats', async (req, res) => {
  try {
    const response = await axios.get(`${APP_TIER_URL}/storage/stats`);
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ 
      success: false, 
      error: error.message 
    });
  }
});

app.listen(port, () => {
  console.log(`Web tier (Google Drive Clone) listening at http://localhost:${port}`);
  console.log(`App tier URL: ${APP_TIER_URL}`);
});