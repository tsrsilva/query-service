from pathlib import Path
import sys

from materialize import run_materializer
from run_queries import load_config, run_query_pipeline

DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent.parent / "config" / "config.yaml"


def main(config_path=None):
    if config_path is None:
        config_path = DEFAULT_CONFIG_PATH

    config = load_config(config_path)
    use_inference = config.get("sparql", {}).get("use_inference", False)
    reasoning_enabled = config.get("reasoning", {}).get("enabled", True)

    if use_inference and not reasoning_enabled:
        raise ValueError(
            "sparql.use_inference is true but reasoning.enabled is false. "
            "Enable reasoning or set sparql.use_inference to false."
        )

    if use_inference:
        print("Query inference enabled: materializing the ontology-aware graph.")
        query_input_ttl = run_materializer(config)
    else:
        print("Query inference disabled: querying the asserted input graph.")
        query_input_ttl = config["paths"]["input_ttl"]

    # Run SPARQL queries and write transformed CSV outputs.
    run_query_pipeline(config, query_input_ttl)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)