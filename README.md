# Actual Local AI Studio

Local AI image generation for Windows.

## Install

Download the ZIP, unzip it, then double-click:

```text
start.bat
```

First launch downloads and builds the app files it needs. Leave the computer online until it finishes.

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
