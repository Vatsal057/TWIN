#!/usr/bin/env python3
"""Trim + quantize GloVe vectors into the compact `.nkem` asset the app bundles.

Naamkaran scores every round locally, so the vectors ship inside the app rather
than sitting behind an API. Full GloVe 6B 50d is ~170 MB of text; we keep the
most frequent alphabetic tokens, unit-normalize them and store int16
quantized components, which lands around 5 MB.

Usage:
    python3 tools/build_embeddings.py \
        --input /tmp/glove.6B.50d.txt \
        --output assets/embeddings/glove50.nkem \
        --limit 50000

Binary layout (all little-endian):
    magic       4s      b"NKEM"
    version     uint16  2
    dim         uint16
    count       uint32
    scale       float32   dequant: value = q * scale / 32767
    vocabBytes  uint32    byte length of the vocab block
    vocab       count entries of [uint8 tokenByteLen][utf8 token],
                          in descending frequency order (row 0 = most frequent)
    sortedIndex count * uint32, rows ordered lexicographically by token
    matrix      count * dim int16

Rows stay in frequency order so "search only the most common N words" is a plain
row limit. `sortedIndex` gives the lexicographic view the prefix fallback needs
to binary-search, without re-sorting 50k strings at startup.
"""

from __future__ import annotations

import argparse
import re
import struct
import sys
from pathlib import Path

import numpy as np

MAGIC = b"NKEM"
VERSION = 2
Q_MAX = 32767

# Playable tokens only: lowercase words, optional internal hyphen/apostrophe.
TOKEN_RE = re.compile(r"^[a-z][a-z'\-]*$")
ALLOWED_SINGLE = {"a", "i"}


def acceptable(token: str) -> bool:
    if len(token) > 24:
        return False
    if len(token) == 1:
        return token in ALLOWED_SINGLE
    if not TOKEN_RE.match(token):
        return False
    # Reject tokens that are mostly punctuation, e.g. "--" or "o'".
    letters = sum(ch.isalpha() for ch in token)
    return letters >= max(2, len(token) - 1)


def load(path: Path, limit: int) -> tuple[list[str], np.ndarray]:
    tokens: list[str] = []
    rows: list[np.ndarray] = []
    seen: set[str] = set()
    dim: int | None = None

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            parts = line.rstrip("\n").split(" ")
            if len(parts) < 10:
                continue
            token = parts[0]
            if token in seen or not acceptable(token):
                continue
            values = np.asarray(parts[1:], dtype=np.float32)
            if dim is None:
                dim = values.shape[0]
            elif values.shape[0] != dim:
                continue
            seen.add(token)
            tokens.append(token)
            rows.append(values)
            if len(tokens) >= limit:
                break

    if dim is None or not rows:
        raise SystemExit(f"no usable vectors parsed from {path}")
    return tokens, np.vstack(rows)


def build(tokens: list[str], matrix: np.ndarray, output: Path) -> None:
    # Unit-normalize so cosine similarity is a plain dot product and the
    # quantization scale is uniform across the table.
    norms = np.linalg.norm(matrix, axis=1, keepdims=True)
    norms[norms == 0] = 1.0
    unit = matrix / norms

    # Rows stay in the input's frequency order. A separate index carries the
    # lexicographic ordering for prefix lookups.
    sorted_index = np.asarray(
        sorted(range(len(tokens)), key=lambda i: tokens[i].encode("utf-8")),
        dtype=np.uint32,
    )

    scale = float(np.abs(unit).max())
    quantized = np.rint(unit / scale * Q_MAX).astype(np.int16)

    vocab_block = bytearray()
    for token in tokens:
        encoded = token.encode("utf-8")
        if len(encoded) > 255:
            raise SystemExit(f"token too long: {token}")
        vocab_block.append(len(encoded))
        vocab_block.extend(encoded)

    count, dim = quantized.shape
    header = struct.pack(
        "<4sHHIfI", MAGIC, VERSION, dim, count, scale, len(vocab_block)
    )

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("wb") as handle:
        handle.write(header)
        handle.write(vocab_block)
        handle.write(sorted_index.astype("<u4").tobytes())
        handle.write(quantized.astype("<i2").tobytes())

    # Report the worst-case quantization error so regressions are visible.
    dequantized = quantized.astype(np.float32) * scale / Q_MAX
    sample = min(2000, count)
    rng = np.random.default_rng(7)
    idx = rng.choice(count, size=sample, replace=False)
    dots_exact = unit[idx] @ unit[idx].T
    dots_quant = dequantized[idx] @ dequantized[idx].T
    err = float(np.abs(dots_exact - dots_quant).max())

    size_mb = output.stat().st_size / (1024 * 1024)
    print(f"wrote {output}  {count} tokens x {dim}d  {size_mb:.2f} MB")
    print(f"quant scale {scale:.6f}  max cosine error {err:.6f}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--limit", type=int, default=50000)
    args = parser.parse_args(argv)

    tokens, matrix = load(args.input, args.limit)
    build(tokens, matrix, args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
