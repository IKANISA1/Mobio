from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from inference import FaceModel, CaptureError, MAX_BYTES

model=FaceModel()
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args): pass
    def setup(self):
        super().setup()
        self.connection.settimeout(10)
    def respond(self, status, value):
        data=json.dumps(value,allow_nan=False).encode()
        self.send_response(status)
        self.send_header('Content-Type','application/json')
        self.send_header('Cache-Control','no-store')
        self.send_header('Content-Length',str(len(data)))
        self.end_headers()
        self.wfile.write(data)
    def do_GET(self):
        if self.path!='/health': return self.respond(404,{'code':'NOT_FOUND'})
        self.respond(200,{'model_loaded':True,'model_version':model.contract['version'],'dimensions':model.dimensions})
    def do_POST(self):
        if self.path!='/embed': return self.respond(404,{'code':'NOT_FOUND'})
        try:
            size=int(self.headers.get('Content-Length','0'))
            if not 0<size<=MAX_BYTES: return self.respond(413,{'code':'IMAGE_TOO_LARGE'})
            data=self.rfile.read(size)
            if len(data)!=size: return self.respond(400,{'code':'INVALID_IMAGE'})
            result=model.embed(data)
            self.respond(200,result)
        except CaptureError as error:
            self.respond(503 if error.code=='SERVICE_BUSY' else 422,{'code':error.code})
        except (OSError, ValueError): self.respond(400,{'code':'INVALID_IMAGE'})
        except Exception: self.respond(503,{'code':'MODEL_UNAVAILABLE'})
if __name__=='__main__': ThreadingHTTPServer(('0.0.0.0',8080),Handler).serve_forever()
