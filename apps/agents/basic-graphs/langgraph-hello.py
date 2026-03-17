import argparse
import os
from typing import TypedDict

class State(TypedDict):
    input: str
    processed_text: str

def call_model(state: State):
    prompt = f"Process the following text: {state['input']}"
    response = llm.invoke(prompt)
    return {"processed_text": response}

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Minimal LangGraph hello example.")
    parser.add_argument(
        "--port",
        type=int,
        default=8123,
        help="Local OpenAI-compatible server port (default: 8123).",
    )
    parser.add_argument(
        "--model",
        default="mlx-community/Llama-3.2-3B-Instruct-4bit",
        help="Model name to request from the server.",
    )
    parser.add_argument(
        "--input",
        default="hello",
        help="Input string for the graph.",
    )
    return parser.parse_args()

if __name__ == "__main__":
    args = parse_args()

    from langchain_openai import OpenAI
    from langgraph.graph import END, START, StateGraph

    llm = OpenAI(
        base_url=f"http://localhost:{args.port}/v1",
        api_key=os.environ.get("OPENAI_API_KEY", "local-key"),
        model=args.model,
    )

    builder = StateGraph(State)
    builder.add_node("call_model", call_model)
    builder.add_edge(START, "call_model")
    builder.add_edge("call_model", END)

    graph = builder.compile()

    # Save the graph as a PNG
    try:
        print(graph.get_graph().print_ascii())
    except Exception as e:
        print(f"Error drawing graph: {e}")

    # Note: this toy graph doesn't call the LLM yet; `llm` is created so the
    # script is ready for the next step where a node uses it.
    result = graph.invoke({"input": args.input})
    print(result)