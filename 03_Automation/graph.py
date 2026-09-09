"""
graph.py — LangGraph pipeline definition for VP EA optimization loop.

Pipeline flow:
  compile_ea → run_backtest → check_data → run_analysis → verify_guards
                                                              ↓
                                            (if guard_updated) → compile_ea (loop)
                                            (if not updated or max iterations) → END

Usage:
    python graph.py              # Run one full cycle
    python graph.py --loop 3    # Run up to 3 iterations
"""
import sys
from typing import TypedDict, Optional
from langgraph.graph import StateGraph, END

from nodes import compile_ea, run_backtest, check_data, run_analysis, verify_guards
from config import MAX_ITERATIONS


# ─── State Schema ─────────────────────────────────────────────────────────────

class PipelineState(TypedDict, total=False):
    # Control flow
    iteration: int
    max_iterations: int
    last_step: str
    error: Optional[str]

    # Step results
    compile_success: bool
    compile_errors: int
    compile_warnings: int
    backtest_success: bool
    backtest_duration_sec: float
    data_sufficient: bool
    total_trades: int
    total_funnel: int
    analysis_success: bool
    guard_updated: bool
    guards_valid: bool
    guard_lines: int


# ─── Routing Logic ────────────────────────────────────────────────────────────

def should_loop(state: PipelineState) -> str:
    """Decide whether to loop back to compile or finish."""
    if state.get("error"):
        return "end"

    if not state.get("guard_updated"):
        print("\n  [DECISION] VPEdgeGuard not updated — converged. Done.")
        return "end"

    iteration = state.get("iteration", 1)
    max_iter  = state.get("max_iterations", MAX_ITERATIONS)
    if iteration >= max_iter:
        print(f"\n  [DECISION] Max iterations ({max_iter}) reached. Done.")
        return "end"

    print(f"\n  [DECISION] VPEdgeGuard updated — looping to recompile (iteration {iteration + 1})")
    return "loop"


def increment_iteration(state: PipelineState) -> PipelineState:
    """Increment iteration counter before looping."""
    state["iteration"]     = state.get("iteration", 1) + 1
    state["error"]         = None
    state["guard_updated"] = False
    return state


# ─── Graph Construction ───────────────────────────────────────────────────────

def build_graph() -> StateGraph:
    """Build the LangGraph state graph for the VP EA automation pipeline."""
    graph = StateGraph(PipelineState)

    graph.add_node("compile_ea",          compile_ea)
    graph.add_node("run_backtest",        run_backtest)
    graph.add_node("check_data",          check_data)
    graph.add_node("run_analysis",        run_analysis)
    graph.add_node("verify_guards",       verify_guards)
    graph.add_node("increment_iteration", increment_iteration)

    graph.add_edge("compile_ea",    "run_backtest")
    graph.add_edge("run_backtest",  "check_data")
    graph.add_edge("check_data",    "run_analysis")
    graph.add_edge("run_analysis",  "verify_guards")

    graph.add_conditional_edges(
        "verify_guards",
        should_loop,
        {"loop": "increment_iteration", "end": END},
    )
    graph.add_edge("increment_iteration", "compile_ea")

    graph.set_entry_point("compile_ea")
    return graph


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    import argparse
    parser = argparse.ArgumentParser(description="VP EA Optimization Pipeline (LangGraph)")
    parser.add_argument("--loop", type=int, default=MAX_ITERATIONS,
                        help=f"Max iterations (default: {MAX_ITERATIONS})")
    parser.add_argument("--skip-backtest", action="store_true",
                        help="Skip backtest step (use existing data)")
    args = parser.parse_args()

    print("\n" + "█" * 60)
    print("  VP EA OPTIMIZATION PIPELINE — LangGraph Orchestrator")
    print(f"  Max iterations: {args.loop}")
    print("█" * 60)

    graph = build_graph()
    app   = graph.compile()

    initial_state: PipelineState = {
        "iteration":        1,
        "max_iterations":   args.loop,
        "error":            None,
        "compile_success":  False,
        "backtest_success": args.skip_backtest,
        "data_sufficient":  args.skip_backtest,
    }

    if args.skip_backtest:
        print("\n  [INFO] --skip-backtest: using existing data")

    final_state = app.invoke(initial_state)

    print("\n" + "█" * 60)
    print("  PIPELINE COMPLETE")
    print("█" * 60)
    print(f"  Iterations run:  {final_state.get('iteration', 1)}")
    print(f"  Last step:       {final_state.get('last_step', 'unknown')}")
    print(f"  Compile:         {'OK' if final_state.get('compile_success') else 'FAIL'}")
    print(f"  Backtest:        {'OK' if final_state.get('backtest_success') else 'FAIL/SKIP'}")
    print(f"  Data:            {final_state.get('total_trades', 0)} trades / {final_state.get('total_funnel', 0)} funnel")
    print(f"  Analysis:        {'OK' if final_state.get('analysis_success') else 'FAIL/SKIP'}")
    print(f"  Guards:          {'VALID' if final_state.get('guards_valid') else 'N/A'} ({final_state.get('guard_lines', 0)} lines)")
    if final_state.get("error"):
        print(f"  Error:           {final_state['error']}")
    print("█" * 60)


if __name__ == "__main__":
    main()
