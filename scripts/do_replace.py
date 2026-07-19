#!/usr/bin/env python3
import io
import sys

path = r"d:\Documents\Learning_Material\SU26\SEP490\Project\Nailify_Mobile_TryOn\android\app\src\main\java\com\google\mediapipe\examples\handlandmarker\OverlayView.kt"

with io.open(path, 'r', encoding='utf-8') as f:
    content = f.read()

print(f"File size: {len(content)} chars")

# Locate the for loop
needle = "for (fingerIndex in 0..4) {\n                val tipIdx = FingerMetrics.FINGER_TIPS[fingerIndex]"
idx = content.find(needle)
print(f"Index of target loop: {idx}")

if idx < 0:
    print("Not found, trying with different newline")
    needle2 = needle.replace('\n', '\r\n')
    idx = content.find(needle2)
    print(f"Index (CRLF): {idx}")
    if idx < 0:
        # Try printing context
        all_indices = []
        pos = 0
        while True:
            p = content.find("val tipIdx = FingerMetrics.FINGER_TIPS[fingerIndex]", pos)
            if p < 0: break
            all_indices.append(p)
            pos = p + 1
        print(f"All occurrences: {all_indices}")
        sys.exit(1)

# Read surrounding context
with io.open(path, 'rb', buffering=0) as f:
    pass
# Print without repr issues using ascii escape
ctx_before = content[max(0, idx-100):idx].encode('ascii', 'replace').decode('ascii')
print("Context OK")
print(f"Indent at idx: {repr(content[idx:idx+30])}")

# Replace the loop with one that goes through DRAW_ORDER
old_block = """            for (fingerIndex in 0..4) {
                val tipIdx = FingerMetrics.FINGER_TIPS[fingerIndex]"""

new_block = """            // GRAPH-BASED FINGER PRESENCE: skip fingers that are not really there
            // (Missing / amputated / hidden behind another finger). Determined by MCP->TIP
            // distance ratio relative to MCP->PIP - structural signal, not prediction.
            val fingerPresentMap = HandGraph.detectPresentFingers(landmark)
            PipelineLogger.log(PipelineLogger.METRICS, 1) {
                val presentStr = fingerPresentMap.filter { it.value }.keys.joinToString(",") { it.graphId }
                val absentStr = fingerPresentMap.filter { !it.value }.keys.joinToString(",") { it.graphId }
                "HAND_${'$'}{handIdx} fingers: present=${'$'}{presentStr} missing=${'$'}{absentStr}"
            }

            for ((fingerIndex, fingerEnum) in HandGraph.Finger.DRAW_ORDER.withIndex()) {
                if (fingerPresentMap[fingerEnum] != true) {
                    PipelineLogger.log(PipelineLogger.METRICS, 2) {
                        "SKIP [ABSENT] ${'$'}{fingerEnum.graphId} - MCP->TIP ratio too low"
                    }
                    stats["ABSENT"] = (stats["ABSENT"] ?: 0) + 1
                    filtersX[fingerIndex].reset()
                    filtersY[fingerIndex].reset()
                    continue
                }
                val tipIdx = FingerMetrics.FINGER_TIPS[fingerIndex]"""

# Check exact match
assert content[idx:idx+len(old_block)] == old_block, "Block mismatch"
print("Block matches exactly. Replacing...")
content = content[:idx] + new_block + content[idx + len(old_block):]

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Done. New file size:", len(content))
