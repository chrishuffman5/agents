# Dataset prep tooling, dedup construction, licensing, and PII

Read when building the pipeline between raw sources and trainer input, when writing a dataset card, or when scrubbing PII.

## Dataset inspection/prep tooling (`datasets` library)

> Source: https://huggingface.co/docs/datasets/en/process

Core operations for tidying a dataset before training. All return a **new** `Dataset` — never in-place.

**Sort / shuffle / select / split / shard**

- `dataset.sort("label")` — sort by a NumPy-compatible column.
- `dataset.shuffle(seed=42)` — random reorder. Once a dataset has an indices mapping (from shuffle/select/filter with non-contiguous indices), row access can be ~10x slower; call `dataset.flatten_indices()` to rewrite to disk and restore speed. For streaming, use `dataset.to_iterable_dataset(num_shards=128)` then `IterableDataset.shuffle(seed=42, buffer_size=1000)` for fast approximate shuffling.
- `dataset.select([0, 10, 20])` — keep specific row indices.
- `dataset.filter(lambda ex: ex["sentence1"].startswith("Ar"))` — keep rows matching a predicate; add `with_indices=True` to receive `idx` as a second lambda arg.
- `dataset.train_test_split(test_size=0.1)` — creates shuffled-by-default train/test splits; `shuffle=False` to disable.
- `dataset.shard(num_shards=4, index=0)` — split a large dataset into N chunks and return chunk `index`.

**Column ops**: `rename_column(old, new)`, `remove_columns([...])`, `select_columns([...])`, `cast(new_features)` / `cast_column(name, new_type)`, `flatten()` (expands nested subfields — e.g. `answers.text` from a SQuAD-style `answers: {text, answer_start}` field — into top-level columns).

**`map()`** — the main transformation primitive. Takes and returns a `dict`. Supports `remove_columns=[...]`, `with_indices=True`, `num_proc=N` for multiprocessing, `with_rank=True` for per-process GPU assignment (requires `multiprocess.set_start_method("spawn")` before any CUDA use, or you hit `RuntimeError: Cannot re-initialize CUDA in forked subprocess`), and `batched=True` (default `batch_size=1000`) for batch-level transforms such as splitting long examples into chunks or LLM-based augmentation. `map()` also supports `async`/`await` functions (e.g. calling a model API per example) — bound concurrency with an `asyncio.Semaphore(N)` to avoid rate-limit errors; up to 1000 map calls run in parallel by default.

**`DatasetDict.map()`** applies one function across every split (train/validation/test) at once.

**`batch(batch_size=4)`** — groups rows into fixed-size batches within a `Dataset`, distinct from `map(batched=True)` which processes in batches but returns an unbatched dataset. Params: `batch_size`, `drop_last_batch` (default `False`), `num_proc`.

**`concatenate_datasets([d1, d2])`** — stack datasets with identical column types (requires `d1.features.type == d2.features.type`); `axis=1` concatenates columns instead of rows (equal row counts required).

**`interleave_datasets([d1, d2, d3], probabilities=[...], seed=..., stopping_strategy=...)`** — mix sources by sampling. `stopping_strategy="first_exhausted"` (default, subsampling — stop once any source runs out), `"all_exhausted"` (oversampling — cycle exhausted sources until every sample from every source has appeared at least once), `"all_exhausted_without_replacement"` (every sample seen exactly once).

**Formats**: `with_format(type="torch"|"numpy"|"tensorflow"|"jax"|"pandas"|"polars"|"arrow")` for on-the-fly conversion; `set_format()` is the in-place variant; `with_transform()` / `set_transform()` apply a fully custom per-access transform (on-the-fly tokenization, custom audio decoding).

**Save/export**: `push_to_hub("user/dataset", num_proc=8)` writes Parquet to the Hub (or an `hf://` bucket path); `save_to_disk()` / `load_from_disk()` for local Arrow (uncompressed, faster reload, less suited to long-term storage than Parquet). Export helpers: `to_csv()`, `to_json()`, `to_parquet()`, `to_sql()`, `to_pandas()` / `to_polars()` / `to_dict()`.

### Deduplication and decontamination pipelines

Documented implication: the library exposes **no single built-in "deduplicate" call** in this guide. Build the pass from the documented primitives — `map()` to compute a normalized hash or n-gram signature per row as a new column, then `filter()` to drop rows whose signature was already seen or that match an eval-benchmark signature.

**Unverified.** No vendor-documented near-duplicate algorithm, MinHash/LSH parameters, shingle size, similarity threshold, or benchmark-overlap n-gram cutoff appears in this corpus. Treat any specific threshold as an engineering judgment call to be validated on your own held-out data, and label it as such rather than presenting it as vendor guidance.

## Dataset card metadata: license and structure

> Source: https://huggingface.co/docs/hub/datasets-cards

A dataset card is the repo's `README.md`, rendered on the dataset's Hub page. A YAML metadata block at the top drives Hub UI behavior (filtering/discovery, license badge, data-file configuration):

```yaml
language:
- "List of ISO 639-1 code for your language"
- lang1
- lang2
pretty_name: "Pretty Name of the Dataset"
tags:
- tag1
- tag2
license: "any valid license identifier"
task_categories:
- task1
- task2
```

- A recognized license identifier makes the license display on the dataset page automatically.
- Modality can be forced via a tag (`3d`, `audio`, `geospatial`, `image`, `tabular`, `text`, `timeseries`, `video`) instead of relying on auto-detection from file contents.
- A library tag (`argilla`, `dask`, `datasets`, `distilabel`, `fiftyone`, `mlcroissant`, `pandas`, `webdataset`) surfaces "how to load this" snippets for that tool on the dataset page.
- Linking an arXiv paper in the card body auto-tags the repo `arxiv:<PAPER_ID>` and cross-links other Hub models/datasets citing the same paper.

## License identifiers

> Source: https://huggingface.co/docs/hub/repositories-licenses

The `license:` field must use a recognized SPDX-style identifier for the badge to render, e.g.: `apache-2.0`, `mit`, `cc0-1.0`, `cc-by-4.0`, `cc-by-sa-4.0`, `cc-by-nc-4.0`, `cc-by-nc-sa-4.0`, `cc-by-nd-4.0`, `openrail`, `bigscience-openrail-m`, `bigcode-openrail-m`, `odc-by`, `odbl`, `gpl-3.0`, `agpl-3.0`, `lgpl-3.0`, `mpl-2.0`, `bsd-3-clause`, `unlicense`, `wtfpl`, `pddl`, `llama2` / `llama3` / `llama3.1` / `llama3.2` / `llama3.3` / `llama4` (Meta's model license family — relevant when a dataset was itself generated by a Llama model, since some of these licenses impose output-use restrictions), `gemma` (Gemma Terms of Use, same consideration for Gemma-generated synthetic data), `unknown`, `other`.

If none of the standard identifiers fit, set `license: other`, add a `license_name`, and include the full license text in a `LICENSE` file in the repo.

**Practical implication for training-dataset licensing**: when building from model outputs (synthetic data) or from scraped/derived sources, the `license` metadata should reflect both (a) any license on the underlying source data and (b) any output-use terms attached to the generator model (Llama/Gemma community licenses restrict some downstream uses of their outputs). Pick the identifier that is actually most restrictive of the two, or use `other` with an explicit `LICENSE` file describing the combined constraint.

## PII annotation taxonomy (real-world example)

> Source: https://huggingface.co/datasets/bigcode/bigcode-pii-dataset

The BigCode PII dataset — built for training/evaluating PII-redaction models on source code — annotates these entity categories: **Names** (plus `NAME_EXAMPLE` / `NAME_LICENSE` variants for names appearing in code examples or license headers rather than as real personal data), **Usernames** (`USERNAME_EXAMPLE` / `USERNAME_LICENSE`), **Emails** (`EMAIL_EXAMPLE` / `EMAIL_LICENSE`), **IP addresses** (`IP_ADDRESS`), **Keys** (`KEY`), **Passwords** (`PASSWORD`), **IDs** (`ID`), and an **Ambiguous** catch-all.

Scale: 12,099 samples of ~50 lines of code each across 31 programming languages.

Sourcing/annotation method: 1,399 crowd-workers (35 countries, via the Toloka platform) annotated a mix of (a) 7,100 files pre-filtered with regex plus the `detect-secrets` tool to enrich for rare PII types, and (b) 5,100 randomly sampled unfiltered files to avoid pre-filter bias.

Access requires accepting terms restricting use to "training or evaluating models for PII removal" and prohibiting redistribution — a pattern worth noting: some PII datasets are themselves licensed/gated in ways that must be respected when building a downstream training corpus.

The `EXAMPLE` / `LICENSE` sub-tagging convention is worth reusing in any custom PII scrubbing pass: it separates true personal data from names/emails that only look like PII because they appear in boilerplate license headers or documentation examples, avoiding over-redaction.

## Sources

- https://huggingface.co/docs/datasets/en/process
- https://huggingface.co/docs/hub/datasets-cards
- https://huggingface.co/docs/hub/repositories-licenses
- https://huggingface.co/datasets/bigcode/bigcode-pii-dataset

Fetched: 2026-08-05
