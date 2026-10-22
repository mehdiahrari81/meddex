"""Download pinned public weights at provisioning time, never during a patient request."""

from huggingface_hub import snapshot_download

from app.services.prescription_ocr import MODEL_ID, MODEL_REVISION

if __name__ == "__main__":
    path = snapshot_download(
        MODEL_ID,
        revision=MODEL_REVISION,
        allow_patterns=["*.json", "*.txt", "*.model", "pytorch_model.bin"],
    )
    print(path)
