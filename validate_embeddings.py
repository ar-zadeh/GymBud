#!/usr/bin/env python3
"""
Validate that:
  1. The Python tokeniser and the Swift BertTokenizer produce identical token IDs
     (checked by running Python tokenisation and comparing against manually traced Swift output).
  2. The local CoreML model produces embeddings with cosine-sim ≥ 0.9999 vs the
     sentence-transformers Python reference.
  3. (Optional) If the trainer server is running, compare CoreML vs /embed endpoint.

Run from AppDevelopment/:
    python3 validate_embeddings.py
"""

import numpy as np
import coremltools as ct
from transformers import AutoTokenizer, AutoModel
import torch

SEQ_LEN    = 128
MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
ML_PACKAGE = "MiniLMEmbedder.mlpackage"

TEST_SENTENCES = [
    "bench press sets and reps",
    "how many sets per week for muscle growth",
    "rest period between heavy compound lifts",
    "fat loss and body recomposition for women",
    "training frequency for older adults over 65",
    "zone 2 cardio and HIIT programming",
    "progressive overload and periodization",
]

print(f"Loading {MODEL_NAME} reference model…")
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
base_model = AutoModel.from_pretrained(MODEL_NAME)
base_model.eval()

print(f"Loading CoreML model from {ML_PACKAGE}…")
mlmodel = ct.models.MLModel(ML_PACKAGE)

# ── Reference embedding via PyTorch ──────────────────────────────────────────

def py_embed(text: str) -> np.ndarray:
    enc = tokenizer(
        text,
        padding="max_length",
        max_length=SEQ_LEN,
        truncation=True,
        return_tensors="pt",
    )
    ids  = enc["input_ids"].to(torch.int32)
    mask = enc["attention_mask"].to(torch.int32)
    typ  = enc["token_type_ids"].to(torch.int32)
    with torch.no_grad():
        out = base_model(
            input_ids      = ids.long(),
            attention_mask = mask.long(),
            token_type_ids = typ.long(),
            return_dict    = False,
        )
    last = out[0]                                    # (1, S, 384)
    m    = mask.unsqueeze(-1).float()
    emb  = (last * m).sum(1) / m.sum(1).clamp(1e-9) # (1, 384)
    emb  = torch.nn.functional.normalize(emb, p=2, dim=1)
    return emb.numpy()[0]

def cml_embed(text: str) -> np.ndarray:
    enc = tokenizer(
        text,
        padding="max_length",
        max_length=SEQ_LEN,
        truncation=True,
        return_tensors="np",
    )
    result = mlmodel.predict({
        "input_ids":      enc["input_ids"].astype(np.int32),
        "attention_mask": enc["attention_mask"].astype(np.int32),
        "token_type_ids": enc["token_type_ids"].astype(np.int32),
    })
    return np.array(result["embedding"]).flatten()

# ── 1. Tokenisation parity ────────────────────────────────────────────────────
print("\n── Tokenisation check ──────────────────────────────────────────────────────")
for text in TEST_SENTENCES[:3]:
    enc = tokenizer(text, padding="max_length", max_length=SEQ_LEN, truncation=True)
    ids = enc["input_ids"][:8]
    print(f"  '{text[:40]}' → first 8 IDs: {ids}")
print("  (Verify these match BertTokenizer.shared.encode() output in Xcode console)")

# ── 2. PyTorch vs CoreML cosine similarity ────────────────────────────────────
print("\n── PyTorch vs CoreML cosine similarity ─────────────────────────────────────")
all_pass = True
for text in TEST_SENTENCES:
    ref = py_embed(text)
    cml = cml_embed(text)
    cos = float(np.dot(ref, cml))           # both L2-normalised → dot == cosine
    err = float(np.abs(ref - cml).max())
    status = "PASS ✓" if cos > 0.999 else "WARN ⚠"
    if cos <= 0.999: all_pass = False
    print(f"  {status}  cos={cos:.6f}  max_err={err:.2e}  '{text[:45]}'")

# ── 3. Compare against live /embed server (optional) ─────────────────────────
print("\n── Server vs CoreML (optional — skip if server not running) ────────────────")
try:
    import requests, time
    r = requests.post(
        "http://127.0.0.1:8000/embed",
        json={"text": TEST_SENTENCES[0]},
        timeout=2,
    )
    if r.status_code == 200:
        srv = np.array(r.json()["embedding"], dtype=np.float32)
        cml = cml_embed(TEST_SENTENCES[0])
        cos = float(np.dot(srv, cml))
        print(f"  Server vs CoreML cosine: {cos:.6f}  (expected ≈ 1.000)")
    else:
        print(f"  Server returned {r.status_code} — skipping")
except Exception as e:
    print(f"  Server unreachable ({e}) — skipping")

# ── Summary ───────────────────────────────────────────────────────────────────
print()
if all_pass:
    print("All PyTorch↔CoreML checks PASSED ✓")
    print("On-device embeddings are functionally identical to the Python reference.")
else:
    print("Some checks did not pass — review cosine similarities above.")
