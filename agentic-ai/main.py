import uuid
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional

from state.workflow_state import new_workflow_state, WorkflowState
from agents.graph import ceylora_graph

app = FastAPI(title="CEYLORA Agentic AI Service")

# ------------------------------------------------------------
# In-memory store for workflow results (simple, for demo/dev).
# Replace with a database or shared cache if you need this to
# THE survive a restart, or if ASP.NET Core needs to poll status
# from a separate process.
# ---------------------------------------------------------
workflow_store: dict[str, WorkflowState] = {}


class RunWorkflowRequest(BaseModel):
    objective: str
    booking_id: Optional[int] = None
    # Tourist's home country (sent by the backend), used to pick a guide who
    # speaks their language.
    tourist_country: Optional[str] = None


class HealthResponse(BaseModel):
    status: str
    service: str


@app.get("/", tags=["Health"])
def root():
    return {"message": "CEYLORA Agentic AI Service is running"}


@app.get("/health", response_model=HealthResponse, tags=["Health"])
def health_check():
    return HealthResponse(status="ok", service="CEYLORA Agentic AI")


@app.post("/agent/run", tags=["Agent"])
async def run_workflow(request: RunWorkflowRequest):
    """
    Starts a new agent workflow: Planner -> Domain Analysis -> Action -> Validation.
    Called internally by the ASP.NET Core backend only (never directly by React/Flutter).
    """
    workflow_id = str(uuid.uuid4())
    initial_state = new_workflow_state(
        workflow_id, request.objective, request.booking_id, request.tourist_country
    )

    final_state = await ceylora_graph.ainvoke(initial_state)

    # Keep the result in memory so /agent/status can be polled afterwards
    workflow_store[workflow_id] = final_state

    return final_state


@app.get("/agent/status/{workflow_id}", tags=["Agent"])
async def get_workflow_status(workflow_id: str):
    """
    Retrieves the current state of a previously run workflow.
    """
    state = workflow_store.get(workflow_id)
    if state is None:
        raise HTTPException(status_code=404, detail="Workflow not found.")
    return state