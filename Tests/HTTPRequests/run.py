#!/usr/bin/env python3
"""Compile the actual Foundation request implementation and test a local server."""
from pathlib import Path
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import subprocess, tempfile, threading
root=Path(__file__).resolve().parents[2]
class Handler(BaseHTTPRequestHandler):
    def log_message(self,*args):pass
    def do_POST(self):
        data=self.rfile.read(int(self.headers['Content-Length']))
        self.send_response(200);self.end_headers();self.wfile.write(data)
    def do_GET(self):
        if self.path=='/redirect':
            self.send_response(302);self.send_header('Location','/latin');self.end_headers()
        else:
            self.send_response(200)
            if self.path!='/unlabelled':self.send_header('Content-Type','text/plain; charset=iso-8859-1')
            self.end_headers();self.wfile.write('café'.encode('latin1'))
server=ThreadingHTTPServer(('127.0.0.1',0),Handler)
threading.Thread(target=server.serve_forever,daemon=True).start()
try:
    with tempfile.TemporaryDirectory(prefix='metalrack-http-') as directory:
        executable=str(Path(directory)/'http-test')
        subprocess.run(['xcrun','clang','-fobjc-arc','-Wall','-Wextra','-Werror','-Wno-unused-parameter','-framework','Foundation','-I',str(root/'Sources/MetalRackUI/include'),str(root/'Sources/MetalRackUI/Implementation/MRHTTPRequest.m'),str(root/'Tests/HTTPRequests/main.m'),'-o',executable],check=True)
        subprocess.run([executable,f'http://127.0.0.1:{server.server_port}'],check=True,timeout=20)
finally:server.shutdown();server.server_close()
