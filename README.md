# Mayniak AI Studio

Local AI image generation for Windows.

## Install

Download the ZIP, unzip it, then double-click:

```text
setup.bat
```

When setup is done, double-click:

```text
start.bat
```

Setup downloads and builds the app files it needs. Leave the computer online until it finishes.

Setup can download about 5-6 GB before models if the Python image runtime is not already installed.

Models are downloaded separately in the app. Most are 2-7 GB each.

When it is ready, it opens:

```text
http://localhost:1420
```

## Use

1. Open the Model Library.
2. Download a model, or import one you already have.
3. Pick the model.
4. Type a prompt.
5. Click Generate.

Images are saved in the gallery.

## Screenshots

| Generate | Models | Settings |
| --- | --- | --- |
| ![Generate](assets/dashboard.png) | ![Models](assets/models.png) | ![Settings](assets/settings.png) |

## Reset

If the app will not start, run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/reset.ps1
```

Then double-click `start.bat` again.

## License

MIT. See `LICENSE`.
