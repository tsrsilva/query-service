import subprocess
from pathlib import Path
from urllib.parse import unquote, urlparse
from xml.etree import ElementTree

from rdflib import Graph, URIRef

OWL_IMPORTS = "{http://www.w3.org/2002/07/owl#}imports"
RDF_ABOUT = "{http://www.w3.org/1999/02/22-rdf-syntax-ns#}about"
RDF_RESOURCE = "{http://www.w3.org/1999/02/22-rdf-syntax-ns#}resource"
OWL_ONTOLOGY = "{http://www.w3.org/2002/07/owl#}Ontology"


def _bool_arg(value) -> str:
    return "true" if bool(value) else "false"

def _resolve_materialized_path(config: dict) -> str:
    paths = config["paths"]
    return paths.get("materialized_ttl", str(Path(paths["output_dir"]) / "materialized.ttl"))


def _ontology_iris(ontology_file: Path) -> set[str]:
    root = ElementTree.parse(ontology_file).getroot()
    return {
        ontology.attrib[RDF_ABOUT]
        for ontology in root.iter(OWL_ONTOLOGY)
        if RDF_ABOUT in ontology.attrib
    }


def _declared_imports(ontology_file: Path) -> set[str]:
    root = ElementTree.parse(ontology_file).getroot()
    return {
        imported_ontology.attrib[RDF_RESOURCE]
        for imported_ontology in root.iter(OWL_IMPORTS)
        if RDF_RESOURCE in imported_ontology.attrib
    }


def _local_ontology_index(ontology_dir: Path) -> dict[str, Path]:
    index = {}
    for candidate in ontology_dir.glob("*.owl"):
        try:
            for ontology_iri in _ontology_iris(candidate):
                index[ontology_iri] = candidate.resolve()
        except ElementTree.ParseError as error:
            raise ValueError(f"Cannot parse local ontology file {candidate}: {error}") from error
    return index


def _resolve_import(import_iri: str, import_map: dict, ontology_index: dict[str, Path]) -> Path | None:
    configured_path = import_map.get(import_iri)
    if configured_path:
        candidate = Path(configured_path)
        return candidate.resolve() if candidate.is_file() else None

    parsed = urlparse(import_iri)
    if parsed.scheme == "file":
        candidate = Path(unquote(parsed.path))
        return candidate.resolve() if candidate.is_file() else None

    return ontology_index.get(import_iri)


def validate_ontology_import_closure(config: dict, ontology_file: str) -> list[Path]:
    """Resolve the local recursive owl:imports closure used by Materializer."""
    validation_cfg = config.get("reasoning", {}).get("import_validation", {})
    if not validation_cfg.get("enabled", True):
        return [Path(ontology_file).resolve()]

    root_ontology = Path(ontology_file).resolve()
    if not root_ontology.is_file():
        raise ValueError(f"Configured ontology file does not exist: {root_ontology}")

    ontology_dir = Path(config["paths"].get("ontology_dir", root_ontology.parent))
    if not ontology_dir.is_dir():
        raise ValueError(f"Configured ontology directory does not exist: {ontology_dir}")

    ontology_index = _local_ontology_index(ontology_dir)
    import_map = validation_cfg.get("ontology_import_map", {})
    pending = [root_ontology]
    closure = []
    unresolved_imports = []
    visited = set()

    while pending:
        current = pending.pop()
        if current in visited:
            continue
        visited.add(current)
        closure.append(current)

        try:
            imported_iris = _declared_imports(current)
        except ElementTree.ParseError as error:
            raise ValueError(f"Cannot parse ontology imports in {current}: {error}") from error

        for import_iri in imported_iris:
            resolved_import = _resolve_import(import_iri, import_map, ontology_index)
            if resolved_import is None:
                unresolved_imports.append((current, import_iri))
            else:
                pending.append(resolved_import)

    if unresolved_imports:
        details = "\n".join(
            f"- {import_iri} (declared by {declaring_ontology})"
            for declaring_ontology, import_iri in unresolved_imports
        )
        raise ValueError(
            "Ontology import closure is incomplete. Add each dependency to "
            "reasoning.import_validation.ontology_import_map or bundle a local ontology "
            "whose owl:Ontology IRI matches the import.\n"
            f"Unresolved imports:\n{details}"
        )

    print("Validated ontology import closure:")
    for ontology in closure:
        print(f"- {ontology}")
    return closure


def build_local_ontology_closure(config: dict, closure: list[Path]) -> str:
    """Write a flattened local closure so Materializer never fetches imports remotely."""
    validation_cfg = config.get("reasoning", {}).get("import_validation", {})
    if not validation_cfg.get("bundle_closure", True):
        return str(closure[0])

    closure_file = validation_cfg.get(
        "closure_file",
        str(Path(config["paths"]["output_dir"]) / "ontology-closure.owl"),
    )
    closure_path = Path(closure_file)
    closure_path.parent.mkdir(parents=True, exist_ok=True)

    graph = Graph()
    for ontology in closure:
        graph.parse(ontology, format="xml")
    graph.remove((None, URIRef("http://www.w3.org/2002/07/owl#imports"), None))
    graph.serialize(destination=closure_path, format="xml")
    return str(closure_path)


def validate_materialized_entailments(config: dict, input_ttl: str, output_ttl: str) -> None:
    """Require configured ABox entailments before querying materialized data."""
    validation_cfg = config.get("reasoning", {}).get("semantic_validation", {})
    if not validation_cfg.get("enabled", False):
        return

    expected_triples = validation_cfg.get("expected_inferred_triples", [])
    if not expected_triples:
        raise ValueError(
            "reasoning.semantic_validation is enabled but no "
            "expected_inferred_triples are configured"
        )

    source_graph = Graph()
    source_graph.parse(input_ttl, format="turtle")
    materialized_graph = Graph()
    materialized_graph.parse(output_ttl, format="turtle")

    failures = []
    for expected_triple in expected_triples:
        try:
            subject = URIRef(expected_triple["subject"])
            predicate = URIRef(expected_triple["predicate"])
            object_ = URIRef(expected_triple["object"])
            triple = (subject, predicate, object_)
        except (KeyError, TypeError) as error:
            raise ValueError(
                "Each reasoning.semantic_validation.expected_inferred_triples entry "
                "requires subject, predicate, and object URI strings"
            ) from error

        if next(source_graph.triples(triple), None) is not None:
            failures.append(f"Expected inference is already asserted: {triple}")
        elif next(materialized_graph.triples(triple), None) is None:
            failures.append(f"Expected inferred triple is missing: {triple}")

    if failures:
        raise RuntimeError(
            "Materialized graph failed semantic validation.\n" + "\n".join(failures)
        )

    print(f"Validated {len(expected_triples)} expected inferred triple(s).")


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

    closure = validate_ontology_import_closure(config, ontology_file)
    materializer_ontology_file = build_local_ontology_closure(config, closure)

    Path(output_ttl).parent.mkdir(parents=True, exist_ok=True)

    output_path = Path(output_ttl)
    old_mtime = output_path.stat().st_mtime if output_path.exists() else None

    cmd = [
        mcfg["exec_path"],
        "file",
        "--reasoner", reasoner,
        "--ontology-file", materializer_ontology_file,
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

    validate_materialized_entailments(config, input_ttl, output_ttl)

    return output_ttl