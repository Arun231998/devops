# Project 3: Self-Healing CI/CD Pipeline

The **Self-Healing CI/CD Pipeline** demonstrates a closed-loop recovery flow. If unit tests fail in continuous integration, a custom failure agent intercepts the test logs, identifies the buggy source file, queries an LLM for corrected code, and automatically applies the patch.

---

## 🏗️ Architecture Design

```
Push code -> Run tests (pytest) -> Test fails -> Trigger healer -> Generate fix -> Apply Git Patch -> Re-verify
```

---

## 🔍 Healing Mechanism

1. **Log Analysis**: The healer parses stderr outputs using regex patterns to extract the failing file (e.g. `test_app.py` or `app.py`).
2. **Context Assembly**: It reads the file contents and groups them with the failing terminal backtrace as context.
3. **AI Generation**: It prompts the LLM to output the **entire corrected file** without any extra text or formatting notes.
4. **Git Apply**: The script updates the target source file, allowing developers to review changes with `git diff`.
5. **Re-Run Validation**: The pipeline runs tests a second time. If they pass, the self-healing cycle was successful.

---

## 🚀 How to Run & Verify

1. Run the test suite (expected to fail):
   ```bash
   pytest ai-self-healing-ci/test_app.py > pytest_run.log 2>&1 || true
   ```
2. Execute the healer:
   ```bash
   python ai-self-healing-ci/self_healer.py --logs pytest_run.log --file ai-self-healing-ci/test_app.py
   ```
3. Check the git diff:
   ```bash
   git diff ai-self-healing-ci/test_app.py
   ```
   *Expected Result: The failing assertion `assert 1 + 1 == 3` is corrected to `assert 1 + 1 == 2`.*
4. Re-run tests to confirm success:
   ```bash
   pytest ai-self-healing-ci/test_app.py
   ```
