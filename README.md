# Actual Local AI Studio

Run local AI image generation from a simple desktop-style web app.

## Start

Double-click:

```text
start.bat
```

The app opens at:

```text
http://localhost:1420
```

## Use

1. Open the Model Library.
2. Download a model or import one you already have.
3. Pick the model.
4. Type a prompt.
5. Click Generate.

Generated images are saved in the app gallery.

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
