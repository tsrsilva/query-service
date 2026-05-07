import subprocess
from pathlib import Path


def _bool_arg(value) -> str:
    return "true" if bool(value) else "false"

def _resolve_materialized_path(config: dict) -> str:
    paths = config["paths"]
    return paths.get("materialized_ttl", str(Path(paths["output_dir"]) / "materialized.ttl"))


def run_materializer(config: dict) -> str:
    input_ttl = config["paths"]["input_ttl"]
    output_ttl = _resolve_materialized_path(config)

    reasoning_cfg = config.get("reasoning", {})
    if not reasoning_cfg.get("enabled", True):
        return input_ttl

    mcfg = config["reasoning"]["materializer"]
    options = mcfg.get("options", {})

    ontology_file = mcfg.get("ontology_file")
    if not ontology_file:
        ontology_dir = config["paths"].get("ontology_dir")
        ontology_name = mcfg.get("ontology_name")
        if ontology_dir and ontology_name:
            ontology_file = str(Path(ontology_dir) / ontology_name)
        else:
            raise ValueError("Missing ontology file configuration for materializer")

    reasoner = options.get("reasoner")
    if not reasoner:
        raise ValueError("Missing reasoning.materializer.options.reasoner in config")

    Path(output_ttl).parent.mkdir(parents=True, exist_ok=True)

    output_path = Path(output_ttl)
    old_mtime = output_path.stat().st_mtime if output_path.exists() else None

    cmd = [
        mcfg["exec_path"],
        "file",
        "--reasoner", reasoner,
        "--ontology-file", ontology_file,
        "--input", input_ttl,
        "--output", output_ttl,
        "--mark-direct-types", _bool_arg(options.get("mark_direct_types", False)),
        "--output-indirect-types", _bool_arg(options.get("output_indirect_types", False)),
    ]

    proc = subprocess.run(cmd, check=False, capture_output=True, text=True)
    combined_output = (proc.stdout or "") + "\n" + (proc.stderr or "")

    # Some materializer failures print exceptions but still exit 0.
    exception_markers = ("Exception:", "java.lang.Exception")
    if proc.returncode != 0 or any(marker in combined_output for marker in exception_markers):
        raise RuntimeError(
            "Materializer failed.\n"
            f"Command: {' '.join(cmd)}\n"
            f"Exit code: {proc.returncode}\n"
            f"Output:\n{combined_output.strip()}"
        )

    if not output_path.exists():
        raise RuntimeError(
            f"Materializer reported success but output file was not created: {output_ttl}"
        )

    new_mtime = output_path.stat().st_mtime
    if old_mtime is not None and new_mtime <= old_mtime:
        raise RuntimeError(
            "Materializer reported success but did not refresh the output file. "
            "Aborting to avoid querying stale materialized data."
        )

    return output_ttl