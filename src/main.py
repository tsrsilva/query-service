from pathlib import Path
import sys

from materialize import run_materializer
from run_queries import load_config, run_query_pipeline

DEFAULT_CONFIG_PATH = Path(__file__).resolve().parent.parent / "config" / "config.yaml"


def main(config_path=None):
    if config_path is None:
        config_path = DEFAULT_CONFIG_PATH

    config = load_config(config_path)

    # Step 1: materialize input graph (or pass through when disabled)
    materialized_ttl = run_materializer(config)

    # Step 2 + 3: run SPARQL queries and write transformed CSV outputs
    run_query_pipeline(config, materialized_ttl)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else None)