import csv
from collections import defaultdict
from pathlib import Path


def save_results_to_csv(results, output_path):
    """
    Converts SPARQL results into a CSV file.
    """

    output_path = Path(output_path)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    # Get variable names
    headers = [str(h) for h in results.vars]

    with open(output_path, "w", newline="") as f:
        writer = csv.writer(f)

        # Write header
        writer.writerow(headers)

        # Write rows
        for row in results:
            writer.writerow([str(cell) if cell is not None else "" for cell in row])


def pivot_csv_if_configured(csv_path, output_cfg):
    """
    Optional post-processing step for CSV pivoting.
    Enabled only when output.pivot.enabled=true in config.
    """

    pivot_cfg = (output_cfg or {}).get("pivot", {})
    if not pivot_cfg.get("enabled", False):
        return

    row_key = pivot_cfg.get("row_key")
    column_key = pivot_cfg.get("column_key")
    value_key = pivot_cfg.get("value_key")

    if not row_key or not column_key or not value_key:
        raise ValueError("output.pivot requires row_key, column_key, and value_key")

    csv_path = Path(csv_path)
    with open(csv_path, "r", newline="") as f:
        reader = csv.DictReader(f)
        rows = list(reader)
        fieldnames = reader.fieldnames or []

    for required_col in (row_key, column_key, value_key):
        if required_col not in fieldnames:
            raise ValueError(f"Pivot column '{required_col}' not found in {csv_path}")

    columns = []
    column_seen = set()
    pivot_data = defaultdict(dict)

    for row in rows:
        r = row[row_key]
        c = row[column_key]
        v = row[value_key]
        pivot_data[r][c] = v
        if c not in column_seen:
            column_seen.add(c)
            columns.append(c)

    with open(csv_path, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([row_key] + columns)
        for r in sorted(pivot_data.keys()):
            writer.writerow([r] + [pivot_data[r].get(c, "") for c in columns])