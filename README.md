# Query Service

[![CI/CD Pipeline](https://github.com/tsrsilva/query-service/actions/workflows/remote.yaml/badge.svg)](https://github.com/tsrsilva/query-service/actions)

Query Service is a small RDF processing pipeline that runs a configured set of SPARQL queries to generate CSV outputs as validation.

The project is designed to:

- load a YAML configuration file
- optionally materialize an input Turtle graph with the bundled materializer tool (**WIP - see note below**)
- run one or more SPARQL queries over the resulting graph
- save the query results as CSV files

>**Materialization** is implemented in the pipeline, but is currently turned off as default. We are working on it and suggest that external users **DO NOT** use it at this moment.


## Main Components

- `src/main.py`: pipeline entrypoint
- `src/materialize.py`: optional materialization step for the input graph
- `src/run_queries.py`: configuration loading, graph loading, and query execution
- `src/transform.py`: CSV writing and optional pivot transformation
- `config/config.yaml`: project configuration
- `queries/`: SPARQL query files executed by the pipeline
- `data/`: input RDF data and ontologies
- `outputs/`: generated materialized TTL and CSV results

## Running Locally

Install dependencies:

```bash
pip install -r requirements.txt
```

Run the pipeline:

```bash
python src/main.py
```

You can also pass a custom config file path:

```bash
python src/main.py path/to/config.yaml
```

## Project Structure

```
query-service/
├── queries/
│   ├── q1_taxon.sparql
│   ├── q2_structure.sparql
│   └── q3_combined.sparql
│
├── src/
│   ├── main.py
│   ├── run_queries.py
│   ├── transform.py
│   └── materialize.py
│
├── config/
│   └── config.yaml
│
├── data/              
├── outputs/           
│
├── Dockerfile
├── pyproject.toml
├── CHANGELOG.md
└── requirements.txt
```

## Deprecated Functions

- Optionally pivot CSV outputs when configured