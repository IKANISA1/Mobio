# AWS Rekognition Secret Rotation Evidence

Date: 2026-06-13
Status: Completed without recording secret values in this evidence file.

## Local Backup

- New IAM user: `ikanisa-rekognition-prod`
- Local backup folder:
  `/Users/jeanbosco/Downloads/aws-rekognition-prod-keys-20260613-163120`
- Backup files are restricted to owner read/write.
- The access key was tested locally against both Rekognition collections:
  - `mobio-biopay-prod`
  - `lovelies-production-faces`

## Local Env Files Updated

- `/Volumes/PRO-G40/MOBI/mobi_app/.env`
  - `FACE_PROVIDER=aws_rekognition`
  - `AWS_REGION=us-east-1`
  - `AWS_REKOGNITION_COLLECTION_ID=mobio-biopay-prod`
  - AWS key values present and redacted here.
- `/Volumes/PRO-G40/MEMORIES/.env`
  - `FACE_PROVIDER=aws_rekognition`
  - `AWS_REGION=us-east-1`
  - `AWS_REKOGNITION_COLLECTION_ID=lovelies-production-faces`
  - AWS key values present and redacted here.
- `/Volumes/PRO-G40/MEMORIES/.env.production.local`
  - `FACE_PROVIDER=aws_rekognition`
  - `AWS_REGION=us-east-1`
  - `AWS_REKOGNITION_COLLECTION_ID=lovelies-production-faces`
  - AWS key values present and redacted here.

## Supabase Edge Function Secrets Updated

- MOBI project: `paysnhuxngsvzdpwlosv`
  - `FACE_PROVIDER`
  - `AWS_REGION`
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REKOGNITION_COLLECTION_ID`
- MEMORIES/KANDA project: `yxtpdgxaqoqsozhkysty`
  - `FACE_PROVIDER`
  - `AWS_REGION`
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
  - `AWS_REKOGNITION_COLLECTION_ID`

## Cloudflare Worker Secrets Updated

- MEMORIES ML gateway Worker: `lovelies-ml-gateway`
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`
- MEMORIES API Worker production environment: `pictured-api-production`
  - `AWS_ACCESS_KEY_ID`
  - `AWS_SECRET_ACCESS_KEY`

## Runtime Proof

MOBI BioPay face provider health returned:

- `provider=aws_rekognition`
- `production_ready=true`
- `provider_collection_id=mobio-biopay-prod`

MOBI BioPay face provider runtime smoke also created an AWS Face Liveness
session successfully through the deployed Supabase Edge Function.
