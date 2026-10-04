#Planner Agent AI 

import os
from langchain_ollama import ChatOllama
from state.workflow_state import WorkflowState, log_step

llm = ChatOllama(model=os.getenv("OLLAMA_MODEL", "llama3.1"), base_url=os.getenv("OLLAMA_BASE_URL"))


async def planner_node(state: WorkflowState) -> WorkflowState:
    """
    Planner/Coordinator Agent (Student 1's contribution).
    Breaks the user's objective into a structured multi-step plan.
    """
    prompt = f"""You are a trip planning coordinator for CEYLORA, a Sri Lankan tourism platform.
A tourist has this objective: "{state['objective']}"

Break this into a structured plan with these steps, in order:
1. Find matching destinations
2. Find matching hotels
3. Find an available guide and vehicle
4. Get a price quote
5. Validate the plan against budget and rules

Respond with a short numbered plan (max 5 steps), nothing else."""

    response = await llm.ainvoke(prompt)
    plan_text = response.content

    plan = [{"step": i + 1, "description": line.strip()}
            for i, line in enumerate(plan_text.split("\n")) if line.strip()]

    state["plan"] = plan
    log_step(state, "PlannerAgent", "create_plan", plan_text)
    return state