import json
from datetime import datetime
from automation.config.config import REPORTS_DIR
from automation.utils.logger import logger

def generate_html_reports(test_results, metrics):
    logger.info("Generating HTML Reports & Dashboard...")
    html_dir = REPORTS_DIR / "HTML"
    html_dir.mkdir(parents=True, exist_ok=True)

    passed_count = metrics["passed"]
    failed_count = metrics["failed"]
    skipped_count = metrics["skipped"]
    total_count = metrics["total"]
    pass_rate = metrics["pass_rate"]

    rows_html = ""
    for test in test_results:
        status = test["status"]
        badge_cls = "bg-emerald-100 text-emerald-800" if status == "PASS" else ("bg-rose-100 text-rose-800" if status == "FAIL" else "bg-amber-100 text-amber-800")
        
        rows_html += f"""
        <tr class="hover:bg-slate-50 transition-colors text-sm border-b border-slate-100">
            <td class="px-4 py-3 font-mono font-bold text-slate-700">{test['id']}</td>
            <td class="px-4 py-3 font-semibold text-slate-800">{test['module']}</td>
            <td class="px-4 py-3 text-slate-600">{test['name']}</td>
            <td class="px-4 py-3"><span class="px-2.5 py-1 rounded-full text-xs font-black uppercase tracking-wider {badge_cls}">{status}</span></td>
            <td class="px-4 py-3 font-medium text-slate-500">{test['priority']}</td>
            <td class="px-4 py-3 text-right font-mono text-xs text-slate-500">{test.get('duration', 0.1):.3f}s</td>
        </tr>
        """

    execution_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Family Health Connect — E2E Live Test Report</title>
    <script src="https://cdn.tailwindcss.com"></script>
</head>
<body class="bg-slate-50 font-sans antialiased text-slate-900 min-h-screen">
    <div class="max-w-7xl mx-auto px-6 py-10 space-y-8">
        
        <!-- Header -->
        <div class="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 bg-white p-8 rounded-3xl border border-slate-200/80 shadow-sm">
            <div>
                <span class="inline-block text-xs font-black tracking-widest uppercase bg-indigo-50 text-indigo-600 px-3 py-1 rounded-full mb-2">Live E2E Automation Report</span>
                <h1 class="text-3xl font-black tracking-tight text-slate-900">Family Health Connect Test Suite</h1>
                <p class="text-slate-500 text-sm mt-1">Live URL: <a href="{metrics['base_url']}" target="_blank" class="text-indigo-600 underline font-semibold">{metrics['base_url']}</a></p>
            </div>
            <div class="text-right text-xs text-slate-400 font-mono">
                <p>Executed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC')}</p>
                <p>Threshold: <span class="font-bold text-emerald-600">≥95% Pass Required</span></p>
            </div>
        </div>

        <!-- Metrics Cards -->
        <div class="grid grid-cols-2 md:grid-cols-5 gap-4">
            <div class="bg-white p-6 rounded-2xl border border-slate-200/80 shadow-sm">
                <p class="text-xs font-bold text-slate-400 uppercase tracking-wider">Total Tests</p>
                <p class="text-3xl font-black text-slate-900 mt-2">{total_count}</p>
            </div>
            <div class="bg-emerald-50/50 p-6 rounded-2xl border border-emerald-200/60 shadow-sm">
                <p class="text-xs font-bold text-emerald-600 uppercase tracking-wider">Passed</p>
                <p class="text-3xl font-black text-emerald-700 mt-2">{passed_count}</p>
            </div>
            <div class="bg-rose-50/50 p-6 rounded-2xl border border-rose-200/60 shadow-sm">
                <p class="text-xs font-bold text-rose-600 uppercase tracking-wider">Failed</p>
                <p class="text-3xl font-black text-rose-700 mt-2">{failed_count}</p>
            </div>
            <div class="bg-amber-50/50 p-6 rounded-2xl border border-amber-200/60 shadow-sm">
                <p class="text-xs font-bold text-amber-600 uppercase tracking-wider">Skipped</p>
                <p class="text-3xl font-black text-amber-700 mt-2">{skipped_count}</p>
            </div>
            <div class="bg-indigo-50/50 p-6 rounded-2xl border border-indigo-200/60 shadow-sm col-span-2 md:col-span-1">
                <p class="text-xs font-bold text-indigo-600 uppercase tracking-wider">Pass Rate</p>
                <p class="text-3xl font-black text-indigo-700 mt-2">{pass_rate:.1f}%</p>
            </div>
        </div>

        <!-- Test Results Table -->
        <div class="bg-white rounded-3xl border border-slate-200/80 shadow-sm overflow-hidden">
            <div class="p-6 border-b border-slate-100 flex justify-between items-center">
                <h2 class="text-xl font-bold text-slate-900">Executed Test Cases ({total_count})</h2>
                <span class="text-xs font-semibold px-3 py-1 bg-emerald-100 text-emerald-800 rounded-full">STATUS: {metrics['threshold_status']}</span>
            </div>
            <div class="overflow-x-auto">
                <table class="w-full text-left border-collapse">
                    <thead>
                        <tr class="bg-slate-50 text-slate-400 text-xs uppercase font-extrabold tracking-wider border-b border-slate-100">
                            <th class="px-4 py-3">Test ID</th>
                            <th class="px-4 py-3">Module</th>
                            <th class="px-4 py-3">Test Name</th>
                            <th class="px-4 py-3">Status</th>
                            <th class="px-4 py-3">Priority</th>
                            <th class="px-4 py-3 text-right">Duration</th>
                        </tr>
                    </thead>
                    <tbody>
                        {rows_html}
                    </tbody>
                </table>
            </div>
        </div>
    </div>
</body>
</html>
"""

    with open(html_dir / "execution-report.html", "w", encoding="utf-8") as f:
        f.write(execution_html)

    with open(html_dir / "dashboard.html", "w", encoding="utf-8") as f:
        f.write(execution_html)

    logger.info(f"HTML Report & Dashboard written to: {html_dir}")
