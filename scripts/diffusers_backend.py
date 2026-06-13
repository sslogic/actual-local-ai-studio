import argparse
import base64
import io
import json
import sys
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import torch
from diffusers import StableDiffusionPipeline, StableDiffusionXLPipeline
from safetensors import safe_open


PIPE = None
MODEL_NAME = ""
PIPELINE_TYPE = "sd15"
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
PROGRESS = {"active": False, "step": 0, "steps": 0, "speed": "", "decoding": False}


def is_sdxl_model(model_path):
    name = model_path.rsplit("\\", 1)[-1].rsplit("/", 1)[-1].lower()
    name_hint = (
        "sdxl" in name
        or "_xl" in name
        or "-xl" in name
        or "juggernaut" in name
        or "lightning" in name
    )
    try:
        with safe_open(model_path, framework="pt", device="cpu") as checkpoint:
            for key in checkpoint.keys():
                if key.startswith("conditioner.embedders.1."):
                    return True
                if key.startswith("conditioner.embedders.0.") and key.startswith("conditioner.embedders.1.") is False:
                    name_hint = True
                if key.startswith("cond_stage_model."):
                    return False
    except Exception as exc:
        print(f"[diffusers] checkpoint architecture probe failed: {exc}", file=sys.stderr, flush=True)
    return name_hint


def load_pipeline(model_path):
    global PIPE, MODEL_NAME, PIPELINE_TYPE
    MODEL_NAME = model_path.rsplit("\\", 1)[-1].rsplit("/", 1)[-1]
    dtype = torch.float16 if DEVICE == "cuda" else torch.float32
    if is_sdxl_model(model_path):
        PIPELINE_TYPE = "sdxl"
        pipe = StableDiffusionXLPipeline.from_single_file(
            model_path,
            torch_dtype=dtype,
            use_safetensors=True,
        )
    else:
        PIPELINE_TYPE = "sd15"
        pipe = StableDiffusionPipeline.from_single_file(
            model_path,
            torch_dtype=dtype,
            safety_checker=None,
            requires_safety_checker=False,
        )
    pipe = pipe.to(DEVICE)
    pipe.enable_attention_slicing()
    PIPE = pipe


def write_json(handler, status, payload):
    body = json.dumps(payload).encode("utf-8")
    handler.send_response(status)
    handler.send_header("Content-Type", "application/json")
    handler.send_header("Content-Length", str(len(body)))
    handler.send_header("Access-Control-Allow-Origin", "*")
    handler.send_header("Access-Control-Allow-Headers", "Content-Type")
    handler.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
    handler.end_headers()
    handler.wfile.write(body)


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print("[diffusers] " + fmt % args, flush=True)

    def do_OPTIONS(self):
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Methods", "GET,POST,OPTIONS")
        self.end_headers()

    def do_GET(self):
        if self.path == "/v1/models":
            return write_json(self, 200, {"data": [{"id": MODEL_NAME, "object": "model", "pipeline": PIPELINE_TYPE}]})
        if self.path == "/progress":
            return write_json(self, 200, PROGRESS)
        return write_json(self, 404, {"error": "Unknown endpoint"})

    def do_POST(self):
        if self.path not in ("/v1/images/generations", "/sdapi/v1/img2img"):
            return write_json(self, 404, {"error": "Unknown endpoint"})

        try:
            length = int(self.headers.get("content-length", "0"))
            body = json.loads(self.rfile.read(length).decode("utf-8") or "{}")
            size = str(body.get("size") or f"{body.get('width', 512)}x{body.get('height', 512)}")
            width, height = [int(part) for part in size.lower().split("x", 1)]
            width = max(64, min(1024, (width // 8) * 8))
            height = max(64, min(1024, (height // 8) * 8))
            steps = max(1, min(80, int(body.get("steps") or body.get("num_inference_steps") or 20)))
            guidance = float(body.get("cfg_scale") or body.get("guidance_scale") or 7.0)
            seed = int(body.get("seed") if body.get("seed") is not None else -1)
            if seed < 0:
                seed = int(time.time() * 1000) % 2147483647
            generator = torch.Generator(device=DEVICE).manual_seed(seed)

            PROGRESS.update({"active": True, "step": 0, "steps": steps, "speed": "", "decoding": False})
            start_time = time.time()

            def progress_callback(pipe, step_index, timestep, callback_kwargs):
                done = int(step_index) + 1
                elapsed = max(0.001, time.time() - start_time)
                PROGRESS.update({
                    "active": True,
                    "step": done,
                    "steps": steps,
                    "speed": f"{done / elapsed:.2f} it/s",
                    "decoding": False,
                })
                return callback_kwargs

            image = PIPE(
                prompt=body.get("prompt") or "",
                negative_prompt=body.get("negative_prompt") or "",
                width=width,
                height=height,
                num_inference_steps=steps,
                guidance_scale=guidance,
                generator=generator,
                callback_on_step_end=progress_callback,
            ).images[0]
            PROGRESS.update({"active": True, "step": steps, "steps": steps, "speed": PROGRESS.get("speed", ""), "decoding": True})

            buf = io.BytesIO()
            image.save(buf, format="PNG")
            PROGRESS.update({"active": False, "step": 0, "steps": 0, "speed": "", "decoding": False})
            encoded = base64.b64encode(buf.getvalue()).decode("ascii")
            if self.path == "/sdapi/v1/img2img":
                return write_json(self, 200, {"images": [encoded], "parameters": body, "info": json.dumps({"seed": seed})})
            return write_json(self, 200, {"created": int(time.time()), "data": [{"b64_json": encoded, "seed": seed}]})
        except Exception as exc:
            print(f"[diffusers] generation failed: {exc}", file=sys.stderr, flush=True)
            return write_json(self, 500, {"error": str(exc)})


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--port", type=int, default=8080)
    args = parser.parse_args()

    print(f"[diffusers] device={DEVICE}", flush=True)
    if DEVICE == "cuda":
        print(f"[diffusers] gpu={torch.cuda.get_device_name(0)}", flush=True)
    load_pipeline(args.model)
    print(f"[diffusers] model ready: {MODEL_NAME} ({PIPELINE_TYPE})", flush=True)

    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    print(f"[diffusers] listening on 127.0.0.1:{args.port}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
