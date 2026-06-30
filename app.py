import os
import json
import subprocess
import threading
from datetime import datetime
from pathlib import Path
from flask import Flask, render_template, request, jsonify
from flask_cors import CORS
from werkzeug.utils import secure_filename
import logging

app = Flask(__name__, template_folder='templates', static_folder='static')
CORS(app)

# Configuration
SKETCHES_DIR = Path(os.getenv('SKETCHES_DIR', '/sketches/visualizations'))
BUILD_DIR = Path(os.getenv('BUILD_DIR', '/tmp/arduino_build'))
ARDUINO_BOARD = os.getenv('ARDUINO_BOARD', 'arduino:renesas_uno:uno_r4_wifi')
SERIAL_PORT = os.getenv('SERIAL_PORT', '/dev/ttyACM0')
SERIAL_SPEED = os.getenv('SERIAL_SPEED', '115200')
METADATA_FILE = Path('/app/data/metadata.json')

# Ensure directories exist
SKETCHES_DIR.mkdir(parents=True, exist_ok=True)
BUILD_DIR.mkdir(parents=True, exist_ok=True)
METADATA_FILE.parent.mkdir(parents=True, exist_ok=True)

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Global state for compilation/flashing
compilation_state = {
    'status': 'idle',  # idle, compiling, flashing, success, error
    'message': '',
    'current_sketch': None,
    'active_sketch': None
}
state_lock = threading.Lock()


def load_metadata():
    """Load sketch metadata"""
    if METADATA_FILE.exists():
        with open(METADATA_FILE) as f:
            return json.load(f)
    return {'active_sketch': None, 'history': []}


def save_metadata(data):
    """Save sketch metadata"""
    with open(METADATA_FILE, 'w') as f:
        json.dump(data, f, indent=2)


def find_sketches(directory=None, prefix=''):
    """Recursively find all .ino files and build tree structure"""
    if directory is None:
        directory = SKETCHES_DIR
    
    sketches = []
    
    if not directory.exists():
        return sketches
    
    for item in sorted(directory.iterdir()):
        if item.is_file() and item.suffix == '.ino':
            sketch_name = item.stem
            relative_path = str(item.relative_to(SKETCHES_DIR))
            sketches.append({
                'name': sketch_name,
                'path': relative_path,
                'full_path': str(item),
                'folder': prefix + item.parent.name if prefix else item.parent.name,
                'modified': datetime.fromtimestamp(item.stat().st_mtime).isoformat()
            })
        elif item.is_dir() and not item.name.startswith('.'):
            new_prefix = prefix + item.name + '/' if prefix else item.name + '/'
            sketches.extend(find_sketches(item, new_prefix))
    
    return sketches


def compile_sketch(sketch_path):
    """Compile sketch to hex file using Arduino CLI"""
    try:
        build_subdir = BUILD_DIR / sketch_path.replace('/', '_').replace('.ino', '')
        build_subdir.mkdir(parents=True, exist_ok=True)
        
        full_sketch_path = SKETCHES_DIR / sketch_path
        
        logger.info(f"Compiling {sketch_path}...")
        
        # Run Arduino CLI compile
        result = subprocess.run(
            [
                'arduino-cli', 'compile',
                '--fqbn', ARDUINO_BOARD,
                '--output-dir', str(build_subdir),
                str(full_sketch_path)
            ],
            capture_output=True,
            text=True,
            timeout=120
        )
        
        if result.returncode != 0:
            logger.error(f"Compilation failed: {result.stderr}")
            return None, result.stderr
        
        # Find the compiled hex file
        hex_file = list(build_subdir.glob('*.hex'))
        if hex_file:
            logger.info(f"Compilation successful: {hex_file[0]}")
            return str(hex_file[0]), None
        else:
            return None, "No hex file generated"
    
    except subprocess.TimeoutExpired:
        return None, "Compilation timed out"
    except Exception as e:
        logger.error(f"Compilation error: {e}")
        return None, str(e)


def flash_sketch(hex_file_path):
    """Flash hex file to Arduino via avrdude"""
    try:
        logger.info(f"Flashing {hex_file_path}...")
        
        result = subprocess.run(
            [
                'avrdude',
                '-c', 'serial',
                '-p', 'm4809',  # Renesas RA4M1
                '-P', SERIAL_PORT,
                '-b', SERIAL_SPEED,
                '-D',
                '-U', f'flash:w:{hex_file_path}:i'
            ],
            capture_output=True,
            text=True,
            timeout=60
        )
        
        if result.returncode != 0:
            logger.error(f"Flash failed: {result.stderr}")
            return False, result.stderr
        
        logger.info("Flash successful!")
        return True, None
    
    except subprocess.TimeoutExpired:
        return False, "Flash operation timed out"
    except Exception as e:
        logger.error(f"Flash error: {e}")
        return False, str(e)


# Routes

@app.route('/')
def index():
    """Serve main web interface"""
    return render_template('index.html')


@app.route('/api/health')
def health():
    """Health check endpoint"""
    return jsonify({'status': 'healthy'})


@app.route('/api/sketches', methods=['GET'])
def get_sketches():
    """List all available sketches"""
    sketches = find_sketches()
    metadata = load_metadata()
    
    # Enrich with metadata
    for sketch in sketches:
        sketch['is_active'] = sketch['path'] == metadata.get('active_sketch')
    
    return jsonify({
        'sketches': sketches,
        'active_sketch': metadata.get('active_sketch'),
        'total': len(sketches)
    })


@app.route('/api/state')
def get_state():
    """Get current compilation/flash state"""
    with state_lock:
        return jsonify(compilation_state)


@app.route('/api/compile/<path:sketch_path>', methods=['POST'])
def compile_endpoint(sketch_path):
    """Compile a sketch"""
    def do_compile():
        with state_lock:
            compilation_state['status'] = 'compiling'
            compilation_state['current_sketch'] = sketch_path
            compilation_state['message'] = 'Starting compilation...'
        
        hex_file, error = compile_sketch(sketch_path)
        
        if error:
            with state_lock:
                compilation_state['status'] = 'error'
                compilation_state['message'] = error
        else:
            with state_lock:
                compilation_state['status'] = 'success'
                compilation_state['message'] = f'Compiled successfully: {Path(hex_file).name}'
                compilation_state['hex_file'] = hex_file
    
    # Run compilation in background thread
    thread = threading.Thread(target=do_compile)
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'compilation started'})


@app.route('/api/flash/<path:sketch_path>', methods=['POST'])
def flash_endpoint(sketch_path):
    """Compile and flash a sketch"""
    def do_flash():
        with state_lock:
            compilation_state['status'] = 'compiling'
            compilation_state['current_sketch'] = sketch_path
            compilation_state['message'] = 'Compiling...'
        
        hex_file, error = compile_sketch(sketch_path)
        
        if error:
            with state_lock:
                compilation_state['status'] = 'error'
                compilation_state['message'] = f'Compilation failed: {error}'
            return
        
        with state_lock:
            compilation_state['status'] = 'flashing'
            compilation_state['message'] = 'Flashing to Arduino...'
        
        success, error = flash_sketch(hex_file)
        
        if error:
            with state_lock:
                compilation_state['status'] = 'error'
                compilation_state['message'] = f'Flash failed: {error}'
        else:
            # Update metadata
            metadata = load_metadata()
            metadata['active_sketch'] = sketch_path
            metadata.setdefault('history', []).insert(0, {
                'sketch': sketch_path,
                'timestamp': datetime.now().isoformat(),
                'success': True
            })
            # Keep only last 20 entries
            metadata['history'] = metadata['history'][:20]
            save_metadata(metadata)
            
            with state_lock:
                compilation_state['status'] = 'success'
                compilation_state['message'] = f'Successfully flashed: {Path(sketch_path).name}'
                compilation_state['active_sketch'] = sketch_path
    
    thread = threading.Thread(target=do_flash)
    thread.daemon = True
    thread.start()
    
    return jsonify({'status': 'flash started'})


@app.route('/api/upload', methods=['POST'])
def upload_sketch():
    """Upload a new sketch file"""
    if 'file' not in request.files:
        return jsonify({'error': 'No file provided'}), 400
    
    file = request.files['file']
    folder = request.form.get('folder', '')
    
    if not file.filename.endswith('.ino'):
        return jsonify({'error': 'Only .ino files allowed'}), 400
    
    # Determine save path
    if folder:
        save_dir = SKETCHES_DIR / folder
    else:
        save_dir = SKETCHES_DIR
    
    save_dir.mkdir(parents=True, exist_ok=True)
    filename = secure_filename(file.filename)
    filepath = save_dir / filename
    
    file.save(filepath)
    logger.info(f"Uploaded sketch: {filepath}")
    
    return jsonify({
        'status': 'uploaded',
        'path': str(filepath.relative_to(SKETCHES_DIR))
    })


@app.route('/api/history')
def get_history():
    """Get flash history"""
    metadata = load_metadata()
    return jsonify({'history': metadata.get('history', [])})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
