import sys
import re
import io

path = r"d:\Documents\Learning_Material\SU26\SEP490\Project\Nailify_Mobile_TryOn\android\app\src\main\java\com\google\mediapipe\examples\handlandmarker\OverlayView.kt"

with io.open(path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace FINGER_NAMES + FINGER_TIPS/PIPS/MCPS arrays with calls to HandGraph
old_arrays = '''    companion object {
        /** Tên hiển thị của từng ngón. */
        val FINGER_NAMES = listOf("thumb", "index", "middle", "ring", "pinky")

        /** Landmark index của TIP cho từng ngón. */
        val FINGER_TIPS = listOf(4, 8, 12, 16, 20)

        /** Landmark index của PIP cho từng ngón. */
        val FINGER_PIPS = listOf(3, 6, 10, 14, 18)

        /** Landmark index của MCP cho từng ngón. */
        val FINGER_MCPS = listOf(2, 5, 9, 13, 17)

        /** Landmark index của DIP cho từng ngón (= TIP - 1). */
        fun dipIndex(tipIndex: Int) = tipIndex - 1'''

new_arrays = '''    companion object {
        /** Tên hiển thị của từng ngón (theo HandGraph.Finger order). */
        val FINGER_NAMES = HandGraph.Finger.values().map { it.graphId }

        /** Landmark index của TIP cho từng ngón (rút ra từ HandGraph). */
        val FINGER_TIPS = HandGraph.Finger.values().map { HandGraph.tipOf(it).index }

        /** Landmark index của PIP cho từng ngón (rút ra từ HandGraph chain). */
        val FINGER_PIPS = HandGraph.Finger.values().map { HandGraph.chain(it)[1].index }

        /** Landmark index của MCP cho từng ngón (dùng làm anchor cho nail polygon). */
        val FINGER_MCPS = HandGraph.Finger.values().map { HandGraph.mcpOf(it).index }

        /** Landmark index của DIP cho từng ngón (= TIP - 1 trong MediaPipe schema). */
        fun dipIndex(tipIndex: Int) = tipIndex - 1'''

if old_arrays in content:
    content = content.replace(old_arrays, new_arrays)
    print("[OK] Replaced FINGER_NAMES arrays")
else:
    # Try relaxing whitespace
    regex_old = re.compile(
        r'    companion object \{.*?fun dipIndex\(tipIndex: Int\) = tipIndex - 1',
        re.DOTALL
    )
    m = regex_old.search(content)
    if m:
        print(f"[regex match found] len={m.end()-m.start()}")
        content = content[:m.start()] + new_arrays + content[m.end():]
        print("[OK] Replaced via regex")
    else:
        print("[FAIL] Could not find FINGER_NAMES block")
        sys.exit(1)

with io.open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("[OK] Wrote back")

