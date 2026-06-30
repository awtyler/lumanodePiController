#!/usr/bin/env python3
"""
Lumanode CLI - Command line interface for managing sketches
"""

import argparse
import requests
import json
import sys
from pathlib import Path
from datetime import datetime
import subprocess
import time

class LumaNodeCLI:
    def __init__(self, api_url='http://localhost:5000'):
        self.api_url = api_url
        self.session = requests.Session()
    
    def list_sketches(self, verbose=False):
        """List all available sketches"""
        try:
            response = self.session.get(f'{self.api_url}/api/sketches')
            response.raise_for_status()
            data = response.json()
            
            sketches = data['sketches']
            active = data['active_sketch']
            
            if not sketches:
                print("No sketches found")
                return
            
            print(f"\n{'Path':<50} {'Status':<10} {'Modified'}")
            print("-" * 75)
            
            for sketch in sorted(sketches, key=lambda x: x['path']):
                is_active = sketch['is_active']
                status = "● ACTIVE" if is_active else ""
                modified = sketch['modified'].split('T')[0]
                print(f"{sketch['path']:<50} {status:<10} {modified}")
            
            if verbose:
                print(f"\nActive sketch: {active or 'None'}")
                print(f"Total: {len(sketches)} sketches")
        
        except requests.exceptions.ConnectionError:
            print("ERROR: Cannot connect to Lumanode controller")
            print("Make sure the Docker container is running: docker-compose up -d")
            sys.exit(1)
        except Exception as e:
            print(f"ERROR: {e}")
            sys.exit(1)
    
    def get_status(self):
        """Get current status"""
        try:
            response = self.session.get(f'{self.api_url}/api/state')
            response.raise_for_status()
            state = response.json()
            
            print(f"Status: {state['status'].upper()}")
            print(f"Current Sketch: {state['current_sketch'] or 'None'}")
            print(f"Message: {state['message']}")
            
            if state['active_sketch']:
                print(f"Active Sketch: {state['active_sketch']}")
        
        except requests.exceptions.ConnectionError:
            print("ERROR: Cannot connect to Lumanode controller")
            sys.exit(1)
        except Exception as e:
            print(f"ERROR: {e}")
            sys.exit(1)
    
    def flash(self, sketch_path, wait=True):
        """Flash a sketch to the Arduino"""
        try:
            print(f"Flashing: {sketch_path}")
            
            response = self.session.post(
                f'{self.api_url}/api/flash/{sketch_path}'
            )
            response.raise_for_status()
            
            if not wait:
                print("Flash started")
                return True
            
            # Wait for completion
            print("Processing...", end='', flush=True)
            start_time = time.time()
            timeout = 300  # 5 minutes
            
            while time.time() - start_time < timeout:
                state_response = self.session.get(f'{self.api_url}/api/state')
                state = state_response.json()
                
                if state['status'] in ['idle', 'success', 'error']:
                    print("\r" + " " * 20 + "\r", end='')  # Clear spinner
                    
                    if state['status'] == 'success':
                        print(f"✓ {state['message']}")
                        return True
                    elif state['status'] == 'error':
                        print(f"✗ {state['message']}")
                        return False
                    else:
                        print("Done")
                        return True
                
                print(".", end='', flush=True)
                time.sleep(0.5)
            
            print("\nTimeout waiting for flash to complete")
            return False
        
        except requests.exceptions.ConnectionError:
            print("ERROR: Cannot connect to Lumanode controller")
            sys.exit(1)
        except requests.exceptions.HTTPError as e:
            print(f"ERROR: {e}")
            sys.exit(1)
    
    def compile(self, sketch_path, wait=True):
        """Compile a sketch"""
        try:
            print(f"Compiling: {sketch_path}")
            
            response = self.session.post(
                f'{self.api_url}/api/compile/{sketch_path}'
            )
            response.raise_for_status()
            
            if not wait:
                print("Compilation started")
                return True
            
            # Wait for completion
            print("Processing...", end='', flush=True)
            start_time = time.time()
            timeout = 300
            
            while time.time() - start_time < timeout:
                state_response = self.session.get(f'{self.api_url}/api/state')
                state = state_response.json()
                
                if state['status'] in ['idle', 'success', 'error']:
                    print("\r" + " " * 20 + "\r", end='')
                    
                    if state['status'] == 'success':
                        print(f"✓ {state['message']}")
                        return True
                    elif state['status'] == 'error':
                        print(f"✗ {state['message']}")
                        return False
                    else:
                        print("Done")
                        return True
                
                print(".", end='', flush=True)
                time.sleep(0.5)
            
            print("\nTimeout waiting for compilation to complete")
            return False
        
        except requests.exceptions.ConnectionError:
            print("ERROR: Cannot connect to Lumanode controller")
            sys.exit(1)
        except requests.exceptions.HTTPError as e:
            print(f"ERROR: {e}")
            sys.exit(1)
    
    def upload(self, file_path, folder=''):
        """Upload a sketch file"""
        try:
            file_path = Path(file_path)
            
            if not file_path.exists():
                print(f"ERROR: File not found: {file_path}")
                sys.exit(1)
            
            if not file_path.suffix == '.ino':
                print("ERROR: Only .ino files are supported")
                sys.exit(1)
            
            with open(file_path, 'rb') as f:
                files = {'file': f}
                data = {'folder': folder}
                
                print(f"Uploading: {file_path.name}")
                response = self.session.post(
                    f'{self.api_url}/api/upload',
                    files=files,
                    data=data
                )
                response.raise_for_status()
                
                result = response.json()
                print(f"✓ Uploaded to: {result['path']}")
                return True
        
        except requests.exceptions.ConnectionError:
            print("ERROR: Cannot connect to Lumanode controller")
            sys.exit(1)
        except Exception as e:
            print(f"ERROR: {e}")
            sys.exit(1)
    
    def history(self, limit=10):
        """Show flash history"""
        try:
            response = self.session.get(f'{self.api_url}/api/history')
            response.raise_for_status()
            data = response.json()
            
            history = data['history'][:limit]
            
            if not history:
                print("No history")
                return
            
            print(f"\n{'Timestamp':<25} {'Status':<10} {'Sketch'}")
            print("-" * 75)
            
            for entry in history:
                timestamp = datetime.fromisoformat(entry['timestamp']).strftime('%Y-%m-%d %H:%M:%S')
                status = "✓ OK" if entry['success'] else "✗ FAIL"
                print(f"{timestamp:<25} {status:<10} {entry['sketch']}")
        
        except requests.exceptions.ConnectionError:
            print("ERROR: Cannot connect to Lumanode controller")
            sys.exit(1)
        except Exception as e:
            print(f"ERROR: {e}")
            sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description='Lumanode Pi Controller CLI',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog='''
Examples:
  # List all sketches
  lumanode list
  
  # Flash a sketch
  lumanode flash visualizations/mysketch
  
  # Compile only (don't flash)
  lumanode compile visualizations/mysketch
  
  # Upload a new sketch
  lumanode upload mysketch.ino --folder patterns
  
  # Show status
  lumanode status
  
  # Show history
  lumanode history
        '''
    )
    
    parser.add_argument(
        '--api',
        default='http://localhost:5000',
        help='API URL (default: http://localhost:5000)'
    )
    
    subparsers = parser.add_subparsers(dest='command', help='Commands')
    
    # List command
    subparsers.add_parser('list', help='List available sketches')
    
    # Status command
    subparsers.add_parser('status', help='Show current status')
    
    # Flash command
    flash_parser = subparsers.add_parser('flash', help='Compile and flash a sketch')
    flash_parser.add_argument('sketch', help='Sketch path (e.g., visualizations/mysketch)')
    flash_parser.add_argument('--no-wait', action='store_true', help='Don\'t wait for completion')
    
    # Compile command
    compile_parser = subparsers.add_parser('compile', help='Compile a sketch (no flash)')
    compile_parser.add_argument('sketch', help='Sketch path')
    compile_parser.add_argument('--no-wait', action='store_true', help='Don\'t wait for completion')
    
    # Upload command
    upload_parser = subparsers.add_parser('upload', help='Upload a new sketch file')
    upload_parser.add_argument('file', help='Path to .ino file')
    upload_parser.add_argument('--folder', default='', help='Destination folder in visualizations')
    
    # History command
    history_parser = subparsers.add_parser('history', help='Show flash history')
    history_parser.add_argument('--limit', type=int, default=10, help='Number of entries to show')
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        sys.exit(0)
    
    cli = LumaNodeCLI(api_url=args.api)
    
    if args.command == 'list':
        cli.list_sketches(verbose=True)
    elif args.command == 'status':
        cli.get_status()
    elif args.command == 'flash':
        success = cli.flash(args.sketch, wait=not args.no_wait)
        sys.exit(0 if success else 1)
    elif args.command == 'compile':
        success = cli.compile(args.sketch, wait=not args.no_wait)
        sys.exit(0 if success else 1)
    elif args.command == 'upload':
        success = cli.upload(args.file, folder=args.folder)
        sys.exit(0 if success else 1)
    elif args.command == 'history':
        cli.history(limit=args.limit)


if __name__ == '__main__':
    main()
