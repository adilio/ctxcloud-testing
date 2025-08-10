#!/usr/bin/env bash

# dspm-upload-to-s3.sh - Upload DSPM data files to S3 and optionally make public
# Updated to use bucket policies instead of ACLs for public access

set -euo pipefail

function usage() {
  echo "Usage: $0 [--bucket <bucket-name>] [--dir <directory>] [--public]"
  echo ""
  echo "Options:"
  echo "  --bucket    Name of the S3 bucket to upload to"
  echo "  --dir       Directory of files to upload (default: ./dspm_test_data)"
  echo "  --public    Make uploaded files public (uses bucket policy)"
  exit 1
}

# Defaults
BUCKET_NAME=""
UPLOAD_DIR="./dspm_test_data"
MAKE_PUBLIC=false
AWS_REGION=${AWS_DEFAULT_REGION:-$(aws configure get region)}
AWS_REGION=${AWS_REGION:-us-east-1}

# Parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --bucket)
      BUCKET_NAME="$2"
      shift 2
      ;;
    --dir)
      UPLOAD_DIR="$2"
      shift 2
      ;;
    --public)
      MAKE_PUBLIC=true
      shift
      ;;
    *)
      usage
      ;;
  esac
done

# Validate bucket name
if [[ -z "$BUCKET_NAME" ]]; then
  read -rp "Enter S3 bucket name: " BUCKET_NAME
fi

# Ensure AWS CLI is installed
if ! command -v aws &>/dev/null; then
  echo -e "\033[0;31m❌ [ERROR]\033[0m AWS CLI not found. Please install it to continue."
  exit 1
fi

# Make sure the directory exists
if [[ ! -d "$UPLOAD_DIR" ]]; then
  echo -e "\033[0;31m❌ [ERROR]\033[0m Directory '$UPLOAD_DIR' not found."
  exit 1
fi

# Check if bucket exists
BUCKET_EXISTS=true
if ! aws s3 ls "s3://$BUCKET_NAME" &>/dev/null; then
  BUCKET_EXISTS=false
  echo -e "\033[0;36mℹ️  [INFO]\033[0m Bucket does not exist. Creating '$BUCKET_NAME' in region $AWS_REGION..."
  aws s3 mb "s3://$BUCKET_NAME" --region "$AWS_REGION"
fi

# Configure public access if requested
if $MAKE_PUBLIC; then
  if ! $BUCKET_EXISTS; then
    echo -e "\033[1;33m⚠️  [WARNING]\033[0m Configuring new bucket for public access..."
    
    # Disable public access block
    aws s3api put-public-access-block \
      --bucket "$BUCKET_NAME" \
      --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"
    
    # Set ownership controls
    aws s3api put-bucket-ownership-controls \
      --bucket "$BUCKET_NAME" \
      --ownership-controls 'Rules=[{ObjectOwnership="ObjectWriter"}]'
  fi

  # Apply public read bucket policy
  POLICY_TEMPLATE='{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "PublicReadGetObject",
        "Effect": "Allow",
        "Principal": "*",
        "Action": "s3:GetObject",
        "Resource": "arn:aws:s3:::%s/*"
      }
    ]
  }'
  printf -v POLICY "$POLICY_TEMPLATE" "$BUCKET_NAME"
  
  echo -e "\033[1;33m⚠️  [WARNING]\033[0m Applying public read bucket policy..."
  aws s3api put-bucket-policy --bucket "$BUCKET_NAME" --policy "$POLICY"
fi

# Upload files with timestamped prefix
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
UPLOAD_ERROR=0

for file in "$UPLOAD_DIR"/*; do
  [[ -e "$file" ]] || continue  # Handle case with no files
  
  base_file=$(basename "$file")
  s3_path="s3://$BUCKET_NAME/dspm/$TIMESTAMP/$base_file"
  
  echo -e "\033[0;36m⬆️  [INFO]\033[0m Uploading $base_file to $s3_path"
  
  # Upload without ACL
  if aws s3 cp "$file" "$s3_path"; then
    if $MAKE_PUBLIC; then
      echo -e "\033[0;35m🌍 [PUBLIC URL]\033[0m https://$BUCKET_NAME.s3.$AWS_REGION.amazonaws.com/dspm/$TIMESTAMP/$base_file"
    fi
  else
    echo -e "\033[0;31m❌ [ERROR]\033[0m Failed to upload $base_file" >&2
    UPLOAD_ERROR=1
  fi
done

if [[ $UPLOAD_ERROR -eq 0 ]]; then
  echo -e "\033[0;32m✅ [SUCCESS]\033[0m Upload complete."
  
  if $MAKE_PUBLIC; then
    echo -e "\033[1;33m⚠️  [WARNING]\033[0m IMPORTANT: Files are publicly accessible via the URLs above"
    echo "   Use caution with sensitive data. Disable public access when done."
  fi
else
  echo -e "\033[0;31m❌ [ERROR]\033[0m Some files failed to upload. See errors above." >&2
  exit 1
fi