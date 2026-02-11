#!/usr/bin/env bash
#
# Extract frames from a screen recording so you can share them in Cursor chat.
# The AI can view images but not video; paste or @-mention these frames to
# show incorrect behavior.
#
# Usage:
#   ./extract-frames-from-recording.sh path/to/recording.mov
#   ./extract-frames-from-recording.sh path/to/recording.mov 5   # one frame every 5 seconds
#
# Requires: ffmpeg (install with: brew install ffmpeg)

set -e

VIDEO="${1:?Usage: $0 <video-file> [interval-seconds]}"
INTERVAL="${2:-2}"  # one frame every N seconds (default 2)

if ! command -v ffmpeg &>/dev/null; then
  echo "ffmpeg is required. Install with: brew install ffmpeg"
  exit 1
fi

if [[ ! -f "$VIDEO" ]]; then
  echo "File not found: $VIDEO"
  exit 1
fi

OUTDIR="recording-frames"
mkdir -p "$OUTDIR"

# Clear old frames from this folder so we don't mix runs
rm -f "$OUTDIR"/frame_*.png

echo "Extracting one frame every ${INTERVAL}s from: $VIDEO"
ffmpeg -i "$VIDEO" -vf "fps=1/${INTERVAL}" -q:v 2 "$OUTDIR/frame_%04d.png" -y 2>/dev/null

COUNT=$(ls -1 "$OUTDIR"/frame_*.png 2>/dev/null | wc -l | tr -d ' ')
echo ""
echo "Done. $COUNT frames saved to: $OUTDIR/"
echo ""
echo "To share with the AI:"
echo "  1. In Cursor chat, type @ and attach or paste images from $OUTDIR/"
echo "  2. Or drag the frame images into the chat"
echo "  3. Describe what’s wrong at which step (e.g. “frame_0012: button does X instead of Y”)"
echo ""
