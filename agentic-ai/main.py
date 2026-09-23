from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
from planner_agent import PlannerAgent
from domain_analysis_agent import DomainAnalysisAgent

app = FastAPI(
    title="CEYLORA Agentic AI Subsystem",
    description="Microservice hosting Student 1 & Student 2 AI Agents for CEYLORA Smart Tourism Platform.",
    version="1.0.0"
)

planner = PlannerAgent()
domain_agent = DomainAnalysisAgent()

class PlanRequest(BaseModel):
    objective: str
    groupSize: Optional[int] = 2
    durationDays: Optional[int] = 3
    budgetCap: Optional[float] = 40000.0

class DomainMatchRequest(BaseModel):
    plan: dict

@app.get("/")
def read_root():
    return {
        "service": "CEYLORA Agentic AI Microservice",
        "status": "Online",
        "activeAgents": ["Planner/Coordinator Agent", "Domain Analysis Agent"]
    }

@app.post("/api/agent/plan")
def generate_plan(req: PlanRequest):
    """
    Step 1 Agent Workflow: Planner/Coordinator Agent decomposes objective.
    """
    try:
        plan = planner.generate_plan(
            objective=req.objective,
            group_size=req.groupSize or 2,
            duration_days=req.durationDays or 3,
            budget_cap=req.budgetCap or 40000.0
        )
        return plan
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/agent/domain-match")
def domain_match(req: DomainMatchRequest):
    """
    Step 2 Agent Workflow: Domain Analysis Agent calls search_destinations & search_hotels tools.
    """
    try:
        result = domain_agent.execute_domain_matching(req.plan)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/agent/run-student-1-workflow")
def run_student_1_workflow(req: PlanRequest):
    """
    Runs Student 1 Agentic Workflow (Planner -> Domain Analysis) end-to-end.
    """
    try:
        # 1. Planner Agent
        plan = planner.generate_plan(
            objective=req.objective,
            group_size=req.groupSize or 2,
            duration_days=req.durationDays or 3,
            budget_cap=req.budgetCap or 40000.0
        )
        
        # 2. Domain Analysis Agent
        domain_result = domain_agent.execute_domain_matching(plan)

        return {
            "status": "Success",
            "objective": req.objective,
            "plannerOutput": plan,
            "domainAnalysisOutput": domain_result,
            "summary": "Student 1 Agents (Planner & Domain Analysis) executed successfully."
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
