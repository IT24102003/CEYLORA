from langgraph.graph import StateGraph, END
from state.workflow_state import WorkflowState
from agents.planner_agent import planner_node
from agents.domain_agent import domain_analysis_node
from agents.action_agent import action_node
from agents.validation_agent import validation_node


def build_graph():
    """
    Builds the CEYLORA Agentic AI workflow:
    Planner -> Domain Analysis -> Action -> Validation -> (pause for human approval)
    """
    graph = StateGraph(WorkflowState)

    graph.add_node("planner", planner_node)
    graph.add_node("domain_analysis", domain_analysis_node)
    graph.add_node("action", action_node)
    graph.add_node("validation", validation_node)

    graph.set_entry_point("planner")
    graph.add_edge("planner", "domain_analysis")
    graph.add_edge("domain_analysis", "action")
    graph.add_edge("action", "validation")
    graph.add_edge("validation", END)  # workflow pauses here; approval happens via ASP.NET Core

    return graph.compile()


# Compiled graph, ready to invoke
ceylora_graph = build_graph()