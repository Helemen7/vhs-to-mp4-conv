# vhs-to-mp4-conv

A Windows batch script for bulk-transcoding DV-captured AVI archives (e.g. from [WinDV](http://windv.mourek.cz/)) into space-efficient H.264/AAC MP4, with deinterlacing and GPU-accelerated encoding.

## Overview

Raw or lightly-compressed DV captures from MiniDV tapes typically occupy **10–15 GB per tape** (25 Mbps DV25 constant bitrate, 720×576 4:1:1/4:2:0 depending on region). This script performs a lossy transcode to H.264 using hardware-accelerated encoding, yielding **80–95% size reduction** while remaining visually near-transparent relative to the source. The source material's own noise floor (analog tape dropout, chroma bleed) makes aggressive compression largely imperceptible.

## Pipeline

1. **Recursive directory walk**: iterates the source tree, treating each top-level subfolder as a tape/session and preserving that hierarchy in the output.
2. **Deinterlacing**: DV is captured as interlaced fields (typically 25i/50 fields for PAL, bottom-field-first). The script applies `yadif` with field-order auto-detection to reconstruct progressive frames and eliminate combing artifacts on motion, prior to encoding.
3. **Hardware encoding**: uses AMD AMF (`h264_amf`) for the video encode, offloading the transcode to the GPU and leaving the CPU largely idle. Rate control is CQP (constant QP) rather than bitrate-targeted, appropriate for archival transcodes where consistent per-frame quality matters more than a fixed output bitrate.
4. **Container/codec compatibility**: output is `yuv420p` H.264 in MP4 (not HEVC) specifically to guarantee native decode support in Windows Media Player / Photos app without requiring the HEVC Video Extensions codec pack.
5. **Idempotent re-runs**: existing output files are skipped, so an interrupted batch can be safely re-invoked without reprocessing completed files.
6. **Stderr isolation**: FFmpeg's non-fatal decoder warnings (`Concealing bitstream errors`, common with tape dropout) are suppressed from stdout via `-loglevel fatal`; stderr is redirected per-file to a sidecar `.log`, retained only on non-zero exit.

## Requirements

- [FFmpeg](https://www.gyan.dev/ffmpeg/builds/) on `PATH` (verify: `ffmpeg -version`).
- AMD GPU with AMF support (verify: `ffmpeg -encoders | findstr amf`). On non-AMD hardware, substitute `h264_amf` with `h264_nvenc` (NVIDIA) or `libx264` (CPU software encode, which is slower, but codec parity is closer to x264's rate-distortion curve if AMF-specific artifacts are observed).

## Usage

1. Download `vhs-to-mp4-conv.bat`.
2. Set the source/destination paths at the top of the script:
   ```bat
   set "SRC=C:\Tapes"
   set "DEST=C:\Converted_Tapes"
   ```
3. Run the script. Directory structure is mirrored 1:1 under the destination root.
4. Do not interrupt the process mid-file. A `Ctrl+C` mid-encode produces a truncated, non-playable output that will need to be deleted and regenerated on the next run (this is the source of most "file won't open" reports: an incomplete container, not a codec fault).

## Quality tuning

Quality is controlled via QP (Quantization Parameter, 0–51 scale, inverse relationship to quality):

| QP range | Result |
|---|---|
| 16–18 | Near-lossless, largest output |
| 20–22 | High quality (script default) |
| 24–26 | Moderate compression, visible softening on fine detail |
| 30+ | Visible blocking/ringing artifacts |

Adjust `-qp_i` (I-frame/keyframe QP) and `-qp_p` (P-frame QP) in the `ffmpeg` invocation. Lower `qp_i` relative to `qp_p` is standard practice since keyframes carry more perceptual weight and error propagation risk.

## Known issues / troubleshooting

- **Interlacing artifacts (horizontal tearing/misaligned strips) in motion**: caused by encoding interlaced source as progressive without deinterlacing. Fixed by the `yadif` filter in this script; if still present, verify field order detection is correct for your capture (bottom-field-first is typical for PAL DV).
- **Output won't open in Windows Media Player/Photos but plays in VLC**: indicates an HEVC output (VLC has a bundled decoder, WMP/Photos do not without the Microsoft Store HEVC extension). This script targets H.264 specifically to avoid this failure mode.
- **`Concealing bitstream errors` in FFmpeg output**: non-fatal DV decoder warnings from tape read errors (dropout, dirty heads). Does not indicate encode failure; suppressed from console output in this script.

## Notes

- Source files are read-only for this script's purposes. They never get modified or deleted.
- Non-zero exit files leave a `.log` sidecar in the destination folder for diagnosis.

## License

No warranty. Retain source tape captures until output has been spot-checked.
