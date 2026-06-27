import os
import sys
import logging
import argparse
from typing import Optional

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger("self-healer")

class AISelfHealer:
    def __init__(self):
        self.gemini_key = os.getenv("GEMINI_API_KEY")
        self.openai_key = os.getenv("OPENAI_API_KEY")
        self.provider = None

        if self.gemini_key:
            self.provider = "gemini"
            import google.generativeai as genai
            genai.configure(api_key=self.gemini_key)
            self.model = genai.GenerativeModel("gemini-1.5-flash")
            logger.info("Using Google Gemini API as AI provider.")
        elif self.openai_key:
            self.provider = "openai"
            from openai import OpenAI
            self.client = OpenAI(api_key=self.openai_key)
            self.model_name = os.getenv("OPENAI_MODEL_NAME", "gpt-4o-mini")
            logger.info(f"Using OpenAI API ({self.model_name}) as AI provider.")
        else:
            logger.warning("No GEMINI_API_KEY or OPENAI_API_KEY found. Running in DRY-RUN demo mode.")
            self.provider = "dry-run"

    def auto_detect_target(self, log_content: str) -> Optional[str]:
        """Scans the build log to identify the target source file that failed."""
        logger.info("Attempting to auto-detect failing target file from logs...")
        # Search Python test file failures (e.g. FAIL: test_app.py or File "test_app.py", line 12)
        import re
        patterns = [
            r'File "(.*?.py)", line \d+',
            r'FAIL:\s+(.*?.py)',
            r'in\s+([a-zA-Z0-9_\-/]+.py):\d+'
        ]
        for pattern in patterns:
            match = re.search(pattern, log_content)
            if match:
                detected_path = match.group(1).strip()
                logger.info(f"Auto-detected target file: {detected_path}")
                return detected_path
        return None

    def heal(self, log_file: str, target_file: Optional[str] = None):
        """Analyzes log file and heals target file."""
        try:
            with open(log_file, "r") as f:
                log_content = f.read()
        except Exception as e:
            logger.error(f"Failed to read log file {log_file}: {e}")
            sys.exit(1)

        if not target_file:
            target_file = self.auto_detect_target(log_content)
            if not target_file:
                logger.error("Could not auto-detect target file. Please specify --file explicitly.")
                sys.exit(1)

        if not os.path.exists(target_file):
            logger.error(f"Target file does not exist: {target_file}")
            sys.exit(1)

        try:
            with open(target_file, "r") as f:
                source_content = f.read()
        except Exception as e:
            logger.error(f"Failed to read target source file {target_file}: {e}")
            sys.exit(1)

        logger.info(f"Initiating self-healing process for: {target_file}")

        prompt = f"""
You are an expert developer and automated bug-fixing system. Analyze the following CI build failure logs and the source code of the failing file.

CI BUILD FAILURE LOG:
---
{log_content}
---

SOURCE CODE OF FAILING FILE ({target_file}):
---
{source_content}
---

Your task is to fix the bug in the source code so that the build passes.
Provide the ENTIRE corrected source code. Do not include markdown code block syntax (like ```python), explanations, or notes. Output ONLY the raw corrected file contents.
"""

        corrected_code = ""

        if self.provider == "dry-run":
            # Check if this is our test file and fix it for the demo
            if "test_app.py" in target_file and "assert 1 + 1 == 3" in source_content:
                logger.info("Dry-run matching: Deliberately replacing failing test assert with correct assertion.")
                corrected_code = source_content.replace("assert 1 + 1 == 3", "assert 1 + 1 == 2")
            else:
                logger.warning("Dry-run could not matching anything. No healing action taken.")
                corrected_code = source_content
        else:
            try:
                if self.provider == "gemini":
                    response = self.model.generate_content(prompt)
                    corrected_code = response.text
                elif self.provider == "openai":
                    response = self.client.chat.completions.create(
                        model=self.model_name,
                        messages=[{"role": "user", "content": prompt}]
                    )
                    corrected_code = response.choices[0].message.content

                # Clean up potential markdown formatting wrapping the raw response
                corrected_code = corrected_code.strip()
                if corrected_code.startswith("```"):
                    # remove first line
                    lines = corrected_code.splitlines()
                    if lines[0].startswith("```"):
                        lines = lines[1:]
                    if lines[-1].startswith("```"):
                        lines = lines[:-1]
                    corrected_code = "\n".join(lines)
            except Exception as e:
                logger.error(f"Failed to communicate with AI API: {e}")
                sys.exit(1)

        # Write healed file back
        try:
            with open(target_file, "w") as f:
                f.write(corrected_code)
            logger.info(f"Self-healing complete. Successfully updated {target_file}.")
            
            # Print diff
            print("\n" + "="*40 + " GIT DIFF OF HEALED CHANGES " + "="*40)
            os.system(f"git diff {target_file}")
            print("="*108 + "\n")
        except Exception as e:
            logger.error(f"Failed to write healed changes back to {target_file}: {e}")
            sys.exit(1)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="AI CI/CD Self-Healing Script")
    parser.add_argument("--logs", required=True, help="Path to failing CI/CD logs")
    parser.add_argument("--file", help="Path to target file to heal (optional, will attempt to auto-detect if omitted)")
    args = parser.parse_args()

    healer = AISelfHealer()
    healer.heal(args.logs, args.file)
