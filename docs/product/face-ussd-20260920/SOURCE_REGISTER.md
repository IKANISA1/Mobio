# Source register

Research checked on 20 September 2026. These are primary documentation sources. Technical choices and acceptance thresholds in the report are recommendations unless expressly attributed to a source. No repository change, provider benchmark or deployment was performed to prepare the report.

[A] User-supplied “Face enrollment, recognition and payment handoff audit,” audit date 20 September 2026; base commit `9e21d3dc4939eafe52f23fe4fe5cd43f3620b415`. A byte-for-byte copy of the mounted upload is included as ORIGINAL_AUDIT.md. Relevant sections: findings FACE-01 through FACE-09, verification table, controls worth retaining, implementation/completion recommendations. The source findings are not replaced by the updated design; its AWS/liveness recommendations are expressly superseded.

[S01] Cloudflare Containers overview — supported runtime/container architecture and Worker integration. `https://developers.cloudflare.com/containers/`

[S02] Cloudflare Containers limits and instance types — published CPU, memory and disk configurations. `https://developers.cloudflare.com/containers/platform/limits/`

[S03] Cloudflare Containers FAQ — ephemeral disk, model/application cold start, instance lifetime and routing considerations. `https://developers.cloudflare.com/containers/faq/`

[S04] OpenCV Zoo SFace README — recognition model, YuNet integration, ONNX format and Apache 2.0 model-directory licence. `https://raw.githubusercontent.com/opencv/opencv_zoo/main/models/face_recognition_sface/README.md`

[S05] OpenCV Zoo YuNet README and licence — detection model, model/runtime pairing and MIT model-directory licence. `https://raw.githubusercontent.com/opencv/opencv_zoo/main/models/face_detection_yunet/README.md` and `https://raw.githubusercontent.com/opencv/opencv_zoo/main/models/face_detection_yunet/LICENSE`

[S06] OpenCV DNN-based face detection and recognition tutorial — FaceDetectorYN, FaceRecognizerSF, alignment/features and benchmark-specific example thresholds. `https://docs.opencv.org/4.x/d0/dd4/tutorial_dnn_face.html`

[S07] InsightFace official repository — distinction between MIT code and non-commercial-research pretrained models; commercial recognition licensing contacts. `https://github.com/deepinsight/insightface`

[S08] Google ML Kit face detection — explicitly distinguishes face detection from identifying individuals. `https://developers.google.com/ml-kit/vision/face-detection`

[S09] Cloudflare Workers AI catalogue — catalogue reviewed; no documented drop-in identity-recognition model identified for this implementation. `https://developers.cloudflare.com/workers-ai/models/`

[S10] Android common intents, Phone section — ACTION_DIAL versus ACTION_CALL and tel URI guidance. `https://developer.android.com/guide/components/intents-common`

[S11] Apple archived Phone Links documentation — documented handling of star/hash telephone links. This is archived guidance, not a claim of a new 2026 device test. `https://developer.apple.com/library/archive/featuredarticles/iPhoneURLScheme_Reference/PhoneLinks/PhoneLinks.html`

[S12] Cloudflare Vectorize API — cosine/index configuration, query options, asynchronous insert/upsert/delete, vector IDs and metadata. `https://developers.cloudflare.com/vectorize/reference/client-api/`

[S13] Flutter camera package, published by flutter.dev — lifecycle responsibility, permissions and supported integrations. `https://pub.dev/packages/camera`

[S14] Amazon Rekognition ListFaces API — documented metadata/identifier response rather than an export of a replacement model's vectors. `https://docs.aws.amazon.com/rekognition/latest/APIReference/API_ListFaces.html`

[S15] Cloudflare Containers pricing — Workers Paid base, provisioned memory/disk, active CPU and other applicable charges. `https://developers.cloudflare.com/containers/platform/pricing/`

[S16] Cloudflare Vectorize pricing — queried/stored dimensional billing and included allowances. `https://developers.cloudflare.com/vectorize/platform/pricing/`

[S17] Rwanda Data Protection and Privacy Office — official registration and overseas transfer/storage authorization services. `https://dpo.gov.rw/`

[S18] Amazon Rekognition DeleteCollection API — scoped collection deletion operation and effects. `https://docs.aws.amazon.com/rekognition/latest/APIReference/API_DeleteCollection.html`

## Specific unverified matters

The exact inline-number MTN USSD sequence supplied by the user has not been independently established as a current operator contract by this research. Use the existing configured route and real SIM/device acceptance rather than claiming that Android's intent documentation verifies MTN menu syntax.

No selected Cloudflare deployment region/account access, full model-latency measurement, real-user recognition result, commercial InsightFace licence, physical Android/iOS test, production database contract or remote AWS cleanup has been verified in preparing these documents.
