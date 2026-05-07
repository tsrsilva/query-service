import yaml
from pathlib import Path
from typing import Optional
from rdflib import Graph

from transform import pivot_csv_if_configured, save_results_to_csv


# ----------------------------
# CONFIG LOADER
# ----------------------------

LOCAL_ROOT_PATH_PREFIXES = {"data", "queries", "outputs", "tools", "config"}


def _normalize_path_value(value, project_root: Path):
    if not isinstance(value, str) or not value.startswith("/"):
        return value

    candidate = Path(value)
    if candidate.exists():
        return value

    parts = candidate.parts
    if len(parts) < 2 or parts[1] not in LOCAL_ROOT_PATH_PREFIXES:
        return value

    return str(project_root / Path(*parts[1:]))


def _normalize_config_paths(value, project_root: Path):
    if isinstance(value, dict):
        return {key: _normalize_config_paths(val, project_root) for key, val in value.items()}
    if isinstance(value, list):
        return [_normalize_config_paths(item, project_root) for item in value]
    return _normalize_path_value(value, project_root)

def load_config(path="/app/config/config.yaml"):
    config_path = Path(path).resolve()
    with open(config_path, "r") as f:
        config = yaml.safe_load(f)

    project_root = config_path.parent.parent
    return _normalize_config_paths(config, project_root)


# ----------------------------
# RDF GRAPH LOADER
# ----------------------------

def load_graph(path: str) -> Graph:
    g = Graph()
    g.parse(path, format="turtle")
    return g


# ----------------------------
# QUERY LOADER
# ----------------------------

def load_query(path: str) -> str:
    with open(path, "r") as f:
        return f.read()


# ----------------------------
# PARAM INJECTION (simple templating)
# ----------------------------

def inject_params(query: str, dataset_cfg: dict) -> str:
    required = {
        "<TAXON_URI>": "taxon_uri",
        "<STRUCTURE_URI>": "structure_uri",
    }

    for placeholder, cfg_key in required.items():
        if placeholder in query:
            value = (dataset_cfg or {}).get(cfg_key)
            if not value:
                raise ValueError(f"Missing dataset.{cfg_key} for placeholder {placeholder}")
            query = query.replace(placeholder, f"<{value}>")

    return query


# ----------------------------
# EXECUTE SINGLE QUERY
# ----------------------------

def run_query(graph: Graph, query: str):
    return graph.query(query)


def _build_query_output_config(global_output_cfg: dict, query_cfg: dict) -> dict:
    merged_output_cfg = dict(global_output_cfg or {})

    global_pivot_cfg = dict((global_output_cfg or {}).get("pivot", {}))
    query_pivot_cfg = query_cfg.get("pivot")

    if isinstance(query_pivot_cfg, dict):
        global_pivot_cfg.update(query_pivot_cfg)

    if global_pivot_cfg:
        merged_output_cfg["pivot"] = global_pivot_cfg

    return merged_output_cfg


# ----------------------------
# MAIN PIPELINE
# ----------------------------

def run_query_pipeline(config: dict, input_ttl: Optional[str] = None):
    print("Starting query service...")

    # Paths
    if input_ttl is None:
        input_ttl = config["paths"]["input_ttl"]
    if not input_ttl:
        raise ValueError("Missing paths.input_ttl for query pipeline")

    queries_dir = Path(config["paths"]["queries_dir"])
    output_dir = Path(config["paths"]["output_dir"])

    output_dir.mkdir(parents=True, exist_ok=True)

    # Dataset parameters
    dataset_cfg = config.get("dataset", {})
    global_output_cfg = config.get("output", {})

    print(f"Loading RDF graph from {input_ttl}")
    graph = load_graph(input_ttl)

    # ----------------------------
    # Iterate over configured queries
    # ----------------------------

    for query_name, qcfg in config["queries"].items():

        if not qcfg.get("enabled", True):
            print(f"Skipping {query_name} (disabled)")
            continue

        query_file = queries_dir / qcfg["file"]
        output_file = output_dir / qcfg["output"]

        print(f"Running {query_name}...")

        # Load + inject params
        raw_query = load_query(query_file)
        final_query = inject_params(raw_query, dataset_cfg)

        # Execute
        results = run_query(graph, final_query)

        # Save
        save_results_to_csv(results, output_file)
        query_output_cfg = _build_query_output_config(global_output_cfg, qcfg)
        pivot_csv_if_configured(output_file, query_output_cfg)

        print(f"Saved {query_name} → {output_file}")

    print("All queries completed successfully.")


def main():
    config = load_config()
    run_query_pipeline(config)


if __name__ == "__main__":
    main()