import json
import re
from typing import Dict, Any

class PlannerAgent:
    """
    Agent 1: Planner / Coordinator Agent (Student 1)
    Responsibility: Parses unstructured trip prompt/objective into a structured execution DAG plan.
    """
    def __init__(self, name: str = "Planner/Coordinator Agent"):
        self.name = name

    def generate_plan(self, objective: str, group_size: int = 2, duration_days: int = 3, budget_cap: float = 40000.0) -> Dict[str, Any]:
        """
        Decomposes user objective into structured steps and region/category preferences.
        """
        prompt_lower = objective.lower()
        
        # Region inference heuristic
        region = "Hill Country"
        if "cultural" in prompt_lower or "sigiriya" in prompt_lower or "history" in prompt_lower:
            region = "Cultural Triangle"
        elif "beach" in prompt_lower or "mirissa" in prompt_lower or "sea" in prompt_lower or "south" in prompt_lower:
            region = "Southern Coast"
        elif "kandy" in prompt_lower or "temple" in prompt_lower:
            region = "Central Province"

        # Days extraction
        days_match = re.search(r'(\d+)\s*day', prompt_lower)
        if days_match:
            duration_days = int(days_match.group(1))

        # Budget extraction
        budget_match = re.search(r'lkr\s*([\d,]+)', prompt_lower)
        if budget_match:
            budget_cap = float(budget_match.group(1).replace(',', ''))

        plan = {
            "agent": self.name,
            "objective": objective,
            "extractedPreferences": {
                "targetRegion": region,
                "durationDays": duration_days,
                "groupSize": group_size,
                "budgetCapLKR": budget_cap,
                "categories": ["Nature & Adventure", "Culture & Heritage", "Historical & Heritage"]
            },
            "executionSteps": [
                {"stepId": 1, "task": "Decompose prompt into region and budget boundaries", "status": "Completed"},
                {"stepId": 2, "task": "Delegate destination & hotel search to Domain Analysis Agent", "status": "Pending"},
                {"stepId": 3, "task": "Delegate guide & vehicle assignment to Action/Tool Agent", "status": "Pending"},
                {"stepId": 4, "task": "Validate budget & date safety via Safety Agent", "status": "Pending"}
            ]
        }
        return plan
