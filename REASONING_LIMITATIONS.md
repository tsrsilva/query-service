# Reasoning Limitations Report

## Scope

This review covers the materialization and SPARQL query pipeline in:

- `src/materialize.py`
- `src/run_queries.py`
- `src/main.py`
- `config/config.yaml`
- `queries/q1_taxon.sparql`
- `queries/q2_structure.sparql`
- `queries/q3_combined.sparql`

The current ABox is `data/kb.ttl`. A local pipeline execution with `python src/main.py` completed successfully and wrote a materialized Turtle file and all configured CSV outputs.

## Architecture Observed

The pipeline performs two separate operations:

1. `run_materializer` invokes the bundled external Materializer executable with `whelk` as its configured reasoner and writes `outputs/materialized.ttl`.
2. `run_query_pipeline` loads that Turtle file into a standard RDFLib `Graph` and evaluates SPARQL queries against the triples contained in that graph.

The query phase is therefore a plain RDF/SPARQL lookup over the materialized output. It does not itself perform OWL, RDFS, or rule inference.

## ABox Characteristics

The reviewed `data/kb.ttl` contains approximately 5,981 triples. It combines instance assertions with terms from PHB, PMCK, CDAO, RO, BFO, PATO, and other ontologies. Its most frequent predicates include `rdf:type`, `rdfs:label`, PHB phenotype relations, and selected CDAO/RO relations.

The graph includes generated resources with labels such as `has_characteristic some enclosing` and `NOT (has_characteristic some enclosing)`. Labels alone do not give these resources OWL class-expression semantics; their behavior depends on the actual RDF/OWL axioms emitted for them and on the expressivity supported by the materializer.

## Limitations and Risks

### 1. Reasoner expressivity may not cover all OWL constructs

The configured engine is `whelk`. OWL materializers generally support a defined profile or practical subset of OWL rather than all OWL 2 DL reasoning tasks.

Impact: verify the exact Whelk/Materializer support for constructs used by PHB and its imports, especially complex restrictions, complements, intersections, qualified cardinalities, property chains, inverse properties, transitivity, disjointness, and inconsistency detection. Do not assume labeled restriction resources produce entailments by themselves.

### 2. Open-world semantics do not support negative conclusions from absence

OWL/RDF follows the open-world assumption. The absence of a phenotype assertion in `kb.ttl` does not entail that the phenotype is absent. Likewise, a missing materialized triple does not establish a negated fact.

Impact: `NOT (...)` should be represented and queried as an explicit, logically supported assertion. It should not be inferred from an empty query result. This is especially important for phenotype matrices where missing observations may mean unknown, inapplicable, unrecorded, or genuinely absent.

### 3. Inconsistencies are not checked or reported

`src/materialize.py` detects command failures and stale output files, but it does not assess ontology consistency. The subsequent RDFLib query phase also does not report semantic contradictions.

Impact: incompatible type assertions, conflicting qualities, disjoint class membership, or contradictions involving negative restrictions can remain in the materialized graph and yield misleading query results. Under classical OWL semantics, inconsistency can have stronger consequences than a normal data-quality warning.

### 4. Query patterns require exact asserted or materialized predicates

All three query files use direct triple patterns such as `?phenotype phb:0000001 ?anatomical_entity` and direct equality filters for the target taxon or anatomical structure.

Impact: a record modeled through a subproperty, equivalent property, inverse property, superclass/subclass relation, or an indirect partonomy path will not match unless that relation has already been materialized into the exact predicate and direction expected by the query.

### 5. `LIMIT 100` can silently truncate answers

Each configured query ends with `LIMIT 100` without an `ORDER BY`.

Impact: a result set above 100 rows is truncated in implementation-dependent order. The CSV and pivot outputs can then omit valid phenotype assertions without any warning that the result set was incomplete.

### 6. Pivoting can overwrite multiple values

`pivot_csv_if_configured` stores each value as `pivot_data[row_key][column_key] = value`. For repeated taxon/anatomical-entity pairs, later CSV rows replace earlier values.

Impact: multiple qualities, observations, provenance records, or conflicting assertions for the same taxon and structure are silently collapsed to one output cell. This is a reporting limitation, but it can hide evidence that matters for reasoning validation.

## Recommended Validation Checks

1. Expand `reasoning.semantic_validation.expected_inferred_triples` into a regression suite with known subclass, subproperty, inverse-property, and restriction entailments from the ABox.
2. Record the Materializer version, selected reasoner, validated ontology closure, and ontology file hashes with each generated output.
3. Run an ontology consistency check with a reasoner appropriate for the OWL profile used by PHB and its imports.
4. Keep `sparql.use_inference` documented as materialized-graph selection, not query-time reasoning. Add a query-engine inference implementation only if on-demand entailment is required.
5. Add explicit ordering and configurable limits to query files. Detect and report truncation when a limit is reached.
6. Preserve multi-valued pivot cells, for example by emitting one row per assertion or aggregating values deterministically instead of overwriting them.
7. Define a clear data policy for missing, absent, inapplicable, uncertain, and contradicted phenotype information before deriving any negative conclusion.

## Bottom Line

The current implementation is operational for querying either the asserted ABox or a pre-materialized phenotype graph. With `sparql.use_inference: true`, the materialized graph must pass configured expected-entailment checks before queries run. This proves the selected ABox inferences, but it does not establish complete support for every OWL construct. RDFLib does not provide additional query-time inference. Treat empty query results as absence of matching data in the selected graph, not proof of a biological or logical negative.