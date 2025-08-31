#!/usr/bin/env bash
# Simple artifact uploader placeholder.
# If configured, this can upload to S3 (via AWS CLI) or keep local packaging.
# Set ARTIFACT_DEST to an S3 URI like s3://my-bucket/path to enable remote upload.

set -euo pipefail

ARTIFACT_SRC=${1-}
if [[ -z $ARTIFACT_SRC ]]; then
	echo "Usage: $0 <artifact-dir>" >&2
	exit 2
fi

OUT_DIR="$(dirname "$0")/artifacts"
mkdir -p "$OUT_DIR"

BASE_NAME="$(basename "$ARTIFACT_SRC")"
TS=$(date +%s)
TAR_PKG="$OUT_DIR/${BASE_NAME}_${TS}.tar.gz"

tar -czf "$TAR_PKG" -C "$(dirname "$ARTIFACT_SRC")" "$BASE_NAME"
echo "Artifact packaged: $TAR_PKG"

# Optional remote upload
if [[ -n ${ARTIFACT_DEST-} ]]; then
	# If ARTIFACT_DEST starts with s3:// and aws CLI is available, attempt upload
	if [[ $ARTIFACT_DEST == s3://* ]]; then
		if command -v aws >/dev/null 2>&1; then
			echo "Uploading $TAR_PKG to $ARTIFACT_DEST"
			if aws s3 cp "$TAR_PKG" "$ARTIFACT_DEST/"; then
				echo "Upload successful"
			else
				echo "Upload failed; leaving artifact locally at $TAR_PKG" >&2
			fi
		else
			echo "aws CLI not found; cannot upload to S3. Set ARTIFACT_DEST to a local path or install aws CLI." >&2
		fi
	else
		# treat ARTIFACT_DEST as a local directory
		mkdir -p "$ARTIFACT_DEST"
		mv "$TAR_PKG" "$ARTIFACT_DEST/"
		echo "Artifact moved to $ARTIFACT_DEST/$(basename "$TAR_PKG")"
	fi
fi
