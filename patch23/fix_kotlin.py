from pathlib import Path

p = Path("app/src/main/java/com/autopulse/scheduler/MainActivity.kt")
s = p.read_text(encoding="utf-8")
fixes = [
    ("minHeight = dp(", "minimumHeight = dp("),
    ("setText(Scheduler.buttonText(this))", "setText(Scheduler.buttonText(this@MainActivity))"),
    ("adapter = adapter", "setAdapter(adapter)"),
    ("s.orEmpty().toString()", "s?.toString().orEmpty()"),
]
for old, new in fixes:
    if old not in s:
        raise RuntimeError(f"Expected Kotlin source not found: {old}")
    s = s.replace(old, new)
p.write_text(s, encoding="utf-8")
print("Kotlin source adjusted before compilation")
