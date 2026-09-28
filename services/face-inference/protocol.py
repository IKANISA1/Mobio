"""Small shared protocol; importing it never loads a model or downloads artifacts."""
MAX_BYTES = 1_500_000


class CaptureError(Exception):
    def __init__(self, code: str):
        super().__init__(code)
        self.code = code
