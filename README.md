# Actual Local AI Studio

Actual Local AI Studio is a Windows-first local image generation workspace for Stable Diffusion models. It runs from a local web UI, keeps image generation on your machine, and avoids requiring a global Python or Node.js install.

The repository contains the app source, setup scripts, and screenshots. Model weights, generated images, portable runtimes, Python dependencies, backend binaries, and Hugging Face cache files are intentionally not included.

## Features

- Local web UI served at `http://localhost:1420`
- Text-to-image and image-to-image generation workflow
- Local model library for `.safetensors`, `.gguf`, and `.ckpt` files
- Built-in model download/import tools
- CUDA, Vulkan, Diffusers CUDA, and CPU-capable backend flow depending on local hardware and installed runtime files
- Live generation progress, backend status, RAM/VRAM telemetry, and model load state
- Local gallery with saved images and metadata in `app/outputs/`
- One-click Windows launch through `start.bat`

## What Is Not Committed

Large runtime and user data folders are ignored on purpose:

- `app/models/`
- `app/outputs/`
- `app/backend/`
- `app/tools/`
- `app/pydeps/`
- `app/hf-cache/`
- `app/dist/`
- `node_modules/`
- model/checkpoint files such as `.safetensors`, `.gguf`, `.ckpt`, and `.onnx`

This keeps the GitHub repo small and prevents accidentally publishing model weights or generated images.

## Requirements

- Windows 10 or Windows 11
- PowerShell
- A modern browser
- NVIDIA GPU for CUDA acceleration, or AMD/Intel/NVIDIA GPU for Vulkan where supported
- Enough disk space for model files and backend/runtime downloads

CPU fallback is available but much slower than GPU generation.

## Quick Start

1. Download or clone the repository.
2. Double-click `start.bat`.
3. Let the setup script download the portable runtime/backend files if they are missing.
4. Open the UI at `http://localhost:1420`.
5. Add a model through the Model Library tab, paste a Hugging Face model URL, or copy your own model into `app/models/`.
6. Select a model, enter a prompt, adjust generation settings, and generate.

## Development

Frontend source lives in `app/frontend`.

```powershell
cd app/frontend
npm install
npm run build
```

The production build is written to `app/dist/`. The local server is managed by:

```powershell
node scripts/serve.cjs
```

For the bundled portable install, `start.bat` and `scripts/setup.ps1` handle the expected runtime layout.

## Repository Layout

```text
.
|-- start.bat
|-- README.md
|-- LICENSE
|-- assets/
|   |-- dashboard.png
|   |-- models.png
|   `-- settings.png
|-- scripts/
|   |-- setup.ps1
|   |-- reset.ps1
|   |-- serve.cjs
|   `-- diffusers_backend.py
`-- app/
    `-- frontend/
        |-- package.json
        |-- vite.config.js
        `-- src/
```

## Screenshots

| Generation Workspace | Model Library | Image Constraints |
| --- | --- | --- |
| ![Generation workspace](assets/dashboard.png) | ![Model library](assets/models.png) | ![Image constraints](assets/settings.png) |

## Troubleshooting

If setup or launch breaks, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/reset.ps1
```

Then launch again with:

```powershell
.\start.bat
```

If port `1420` is already in use, close the existing app window or set `FRONTEND_PORT` before launch.

## License

MIT. See `LICENSE`.

This project can download or use third-party model files and backend components. Those files are governed by their own licenses and are not included in this repository.
