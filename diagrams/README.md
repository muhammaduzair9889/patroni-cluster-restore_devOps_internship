# Diagrams & Visual Reference

This section contains visual diagrams and flowcharts for cluster architecture and restore process.

## Diagrams Included

### CLUSTER_TOPOLOGY.md
Visual representation of:
- 3-node cluster architecture
- Network connectivity between nodes
- Storage architecture (backup repository)
- Component placement (PostgreSQL, Patroni, etcd)
- Data flow during normal operation

### RESTORE_FLOW.md
Flow diagram showing:
- 9-step restore process
- Decision points
- Parallel and sequential tasks
- Timing expectations
- Success/failure paths

### FAILURE_DECISION_TREE.md
Interactive decision tree for:
- Identifying failure type
- Finding root cause
- Locating quick fix
- Escalation procedures

## Using Diagrams

1. **Understanding System:** Start with CLUSTER_TOPOLOGY.md
2. **Planning Restore:** Review RESTORE_FLOW.md
3. **Troubleshooting:** Follow FAILURE_DECISION_TREE.md

## ASCII Art vs Mermaid

- **ASCII diagrams:** Can be viewed in any text editor
- **Mermaid diagrams:** Render as images in GitHub/web browsers

Choose based on your preference and tools available.

## Creating Your Own

To add custom diagrams:
1. Use ASCII art for text-based (simple, universal)
2. Use Mermaid for flowcharts (prettier, interactive)
3. Use drawing tools for detailed architecture
4. Store images in /diagrams/ directory
5. Link from README.md

## Tools for Creating Diagrams

- **Mermaid:** https://mermaid.live/ (free, online)
- **Graphviz:** https://graphviz.org/ (open source)
- **Draw.io:** https://www.draw.io/ (free, online)
- **Lucidchart:** https://www.lucidchart.com/ (paid)
- **ASCII Art:** Any text editor

---

**Note:** Diagrams are living documents. Update them as procedures change.
