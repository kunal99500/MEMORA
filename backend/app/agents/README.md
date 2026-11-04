# Agent orchestration

The current baseline is deliberately deterministic: capture -> quality -> frame extraction -> optional vision -> observation persistence. Add LangGraph when each node has stable typed input/output contracts. Do not use an LLM for deterministic validation, authorization, database writes, inventory arithmetic or confidence threshold enforcement. Add bounded loops, checkpointing, budgets and human approval for consequential actions.
