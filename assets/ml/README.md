# MobileFaceNet TFLite Model

Place the `mobilefacenet.tflite` model file in this directory.

## Expected Model
- **Input**: `[1, 112, 112, 3]` — RGB face crop normalized to `[-1, 1]`
- **Output**: `[1, N]` — L2-normalized face embedding (N=128 or N=192 depending on model variant)

## Obtaining the Model
The MobileFaceNet model can be obtained from:
1. InsightFace model zoo (ArcFace/MobileFaceNet variants)
2. Convert from ONNX/PyTorch using TFLite converter

The embedding dimension is auto-detected from the output tensor shape.
