#Planner Agent AI 

import os
from state.workflow_state import WorkflowState, log_step


def _build_llm():
    """
    Picks the LLM provider from environment variables, so the same code runs
    both on a laptop (Ollama) and on a cloud host (Groq's hosted API):

      - GROQ_API_KEY set  -> Groq (hosted, free tier; used on Railway)
      - otherwise         -> local Ollama (OLLAMA_MODEL / OLLAMA_BASE_URL)

    Imports are done lazily so a deployment only needs the package for the
    provider it actually uses.
    """
    if os.getenv("GROQ_API_KEY"):
        from langchain_groq import ChatGroq
        return ChatGroq(
            model=os.getenv("GROQ_MODEL", "llama-3.1-8b-instant"),
            temperature=0.2,
            timeout=30,
            max_retries=1,
        )
    from langchain_ollama import ChatOllama
    return ChatOllama(model=os.getenv("OLLAMA_MODEL", "llama3.1"), base_url=os.getenv("OLLAMA_BASE_URL"))


llm = _build_llm()


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