#!/usr/bin/env python3
"""
Convert sentence-transformers/all-MiniLM-L6-v2 to CoreML.

Output: MiniLMEmbedder.mlpackage  (place in Xcode app bundle)
        vocab.txt                  (place in Xcode app bundle)

The model accepts three fixed-length (SEQ_LEN=128) int32 arrays and returns
a 384-dim L2-normalised float32 embedding vector.
"""

import shutil, os
import torch
import numpy as np
from transformers import AutoTokenizer, AutoModel
import coremltools as ct

SEQ_LEN    = 128
MODEL_NAME = "sentence-transformers/all-MiniLM-L6-v2"
OUT_MODEL  = "MiniLMEmbedder.mlpackage"
OUT_VOCAB  = "vocab.txt"

# ── 1. Load model ─────────────────────────────────────────────────────────────
print(f"Loading {MODEL_NAME}…")
tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
model     = AutoModel.from_pretrained(MODEL_NAME)
model.eval()

# ── 2. Wrapper: BERT → mean-pool → L2-norm ────────────────────────────────────
class MiniLMEmbedder(torch.nn.Module):
    def __init__(self, base):
        super().__init__()
        self.model = base

    def forward(self, input_ids, attention_mask, token_type_ids):
        out = self.model(
            input_ids      = input_ids.long(),
            attention_mask = attention_mask.long(),
            token_type_ids = token_type_ids.long(),
            return_dict    = False,
        )
        last_hidden = out[0]                                      # (1, S, 384)
        mask        = attention_mask.unsqueeze(-1).float()        # (1, S, 1)
        sum_emb     = (last_hidden * mask).sum(dim=1)             # (1, 384)
        sum_mask    = mask.sum(dim=1).clamp(min=1e-9)             # (1, 1)
        emb         = sum_emb / sum_mask                          # (1, 384)
        return torch.nn.functional.normalize(emb, p=2, dim=1)    # (1, 384)

wrapper = MiniLMEmbedder(model)
wrapper.eval()

# ── 3. Trace ───────────────────────────────────────────────────────────────────
print("Tracing model…")
dummy = torch.zeros(1, SEQ_LEN, dtype=torch.int32)
with torch.no_grad():
    traced = torch.jit.trace(wrapper, (dummy, dummy, dummy))

# ── 4. Convert to CoreML ───────────────────────────────────────────────────────
print("Converting to CoreML…")
mlmodel = ct.convert(
    traced,
    inputs=[
        ct.TensorType(name="input_ids",      shape=(1, SEQ_LEN), dtype=np.int32),
        ct.TensorType(name="attention_mask",  shape=(1, SEQ_LEN), dtype=np.int32),
        ct.TensorType(name="token_type_ids", shape=(1, SEQ_LEN), dtype=np.int32),
    ],
    outputs=[
        ct.TensorType(name="embedding", dtype=np.float32),
    ],
    minimum_deployment_target=ct.target.iOS16,
    compute_units=ct.ComputeUnit.CPU_AND_NE,
)

mlmodel.save(OUT_MODEL)
print(f"Saved {OUT_MODEL} ✓")

# ── 5. Copy vocab.txt from HuggingFace cache ──────────────────────────────────
vocab_src = tokenizer.vocab_file if hasattr(tokenizer, "vocab_file") else None
if vocab_src and os.path.exists(vocab_src):
    shutil.copy(vocab_src, OUT_VOCAB)
    print(f"Copied vocab.txt ({os.path.getsize(OUT_VOCAB)//1024} KB) ✓")
else:
    # Fallback: save via tokenizer API
    tokenizer.save_vocabulary(".")
    print(f"Saved vocab.txt via tokenizer API ✓")

# ── 6. Validate CoreML output against PyTorch reference ──────────────────────
print("\nValidating…")
text = "bench press sets and reps"
enc  = tokenizer(
    text,
    padding          = "max_length",
    max_length       = SEQ_LEN,
    truncation       = True,
    return_tensors   = "pt",
)
ids  = enc["input_ids"].to(torch.int32)
mask = enc["attention_mask"].to(torch.int32)
typ  = enc["token_type_ids"].to(torch.int32)

with torch.no_grad():
    ref_emb = wrapper(ids, mask, typ).numpy()[0]

cml_result = mlmodel.predict({
    "input_ids":      ids.numpy(),
    "attention_mask": mask.numpy(),
    "token_type_ids": typ.numpy(),
})
cml_emb = np.array(cml_result["embedding"]).flatten()

cos_sim = float(np.dot(ref_emb, cml_emb))   # both are L2-normalised so dot = cosine
max_err  = float(np.abs(ref_emb - cml_emb).max())
print(f"  Cosine similarity PyTorch ↔ CoreML : {cos_sim:.6f}  (target ≈ 1.000)")
print(f"  Max absolute error                 : {max_err:.2e}  (target < 1e-4)")
if cos_sim > 0.9999:
    print("  PASS ✓")
else:
    print("  WARN: cosine sim below threshold — check conversion")

print("\nDone. Add MiniLMEmbedder.mlpackage and vocab.txt to the Xcode project.")
