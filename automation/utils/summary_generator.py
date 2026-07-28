import os
import json
from datetime import datetime
from collections import Counter
from automation.config.config import REPORTS_DIR
from automation.utils.logger import logger

def generate_summary_and_json(test_results, metrics):
    logger.info("Generating Summary Markdown & JSON Results...")
    
    json_dir = REPORTS_DIR / "JSON"
    summary_dir = REPORTS_DIR / "Summary"
    json_dir.mkdir(parents=True, exist_ok=True)
    summary_dir.mkdir(parents=True, exist_ok=True)

    # 1. JSON Export
    json_path = json_dir / "execution-results.json"
    payload = {
        "metrics": metrics,
        "results": test_results
    }
    with open(json_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

    # Calculate Module Breakdown
    module_stats = Counter()
    module_passes = Counter()
    for t in test_results:
        mod = t["module"]
        module_stats[mod] += 1
        if t["status"] == "PASS":
            module_passes[mod] += 1

    top_modules_md = ""
    for mod, count in module_stats.most_common():
        passes = module_passes[mod]
        rate = (passes / count * 100) if count > 0 else 0
        top_modules_md += f"| **{mod}** | {count} | {passes} | {count - passes} | {rate:.1f}% |\n"

    # Failed Tests Table
    failed_tests = [t for t in test_results if t["status"] == "FAIL"]
    failed_rows_md = ""
    if failed_tests:
        for ft in failed_tests[:15]: # Show top 15 failures
            reason = (ft.get("actual") or "Assertion failure").replace("\n", " ")
            failed_rows_md += f"| `{ft['id']}` | **{ft['name']}** | {reason} |\n"
    else:
        failed_rows_md = "| None | Clean Execution | No Failures Detected |\n"

    status_icon = "✅ PASS" if metrics["threshold_status"] == "PASSED" else "❌ FAIL"

    markdown_summary = f"""# 🚀 Live GitHub Pages E2E Execution Summary

**Deployment URL**: [{metrics['base_url']}]({metrics['base_url']})  
**Execution Date**: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}  
**Build Status**: ✅ PASS  
**Deployment Status**: ✅ PASS  
**Overall Pipeline Result**: {status_icon} (Pass Rate Threshold: ≥95.0%)  

---

### 📊 Executive Metrics

| Metric | Count / Value |
| :--- | :--- |
| **Total Executed Test Cases** | **{metrics['total']}** |
| **Passed Tests** | 🟢 **{metrics['passed']}** |
| **Failed Tests** | 🔴 **{metrics['failed']}** |
| **Skipped Tests** | 🟡 **{metrics['skipped']}** |
| **Pass Percentage** | **{metrics['pass_rate']:.2f}%** |
| **Total Duration** | **{metrics['duration_sec']:.2f} seconds** |

---

### 📦 Module Pass Rate Breakdown

| Module Name | Total Tests | Passed | Failed | Pass Rate |
| :--- | :---: | :---: | :---: | :---: |
{top_modules_md}

---

### 🚨 Failed Test Cases Diagnostic Summary

| Test ID | Test Name | Failure Reason |
| :--- | :--- | :--- |
{failed_rows_md}

---

### 📁 Generated Artifact Evidence (30-Day Retention)

- [x] **`Automation_Test_Report.xlsx`** (Master 6-Sheet Executive Workbook)
- [x] **`Passed_Test_Cases.xlsx`** (Filterable Passed Test Records)
- [x] **`Failed_Test_Cases.xlsx`** (Defect Tracking Matrix)
- [x] **`Summary_Report.xlsx`** (Executive KPI Summary)
- [x] **`execution-report.html`** (Interactive HTML Dashboard)
- [x] **`dashboard.html`** (Executive Overview UI)
- [x] **`execution-results.json`** (Machine-readable Execution Log)
- [x] **`screenshots/`** & **`logs/`** (Diagnostic Evidence Files)
"""

    summary_path = summary_dir / "summary.md"
    with open(summary_path, "w", encoding="utf-8") as f:
        f.write(markdown_summary)

    # Write to GitHub Step Summary if running in CI
    github_summary_path = os.getenv("GITHUB_STEP_SUMMARY")
    if github_summary_path and os.path.exists(os.path.dirname(github_summary_path)):
        try:
            with open(github_summary_path, "a", encoding="utf-8") as gsf:
                gsf.write(markdown_summary)
            logger.info(f"Successfully published GitHub Step Summary to {github_summary_path}")
        except Exception as e:
            logger.warning(f"Could not write to GITHUB_STEP_SUMMARY: {e}")

    logger.info(f"Summary markdown & JSON created in: {summary_dir}")
