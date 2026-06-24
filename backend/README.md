# JM Visual Backend

Thin FastAPI adapter around `jmcomic` for the Flutter client.

## Run

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
uvicorn jm_server.app:app --host 127.0.0.1 --port 8766 --reload
```

Useful environment variables:

- `JM_OPTION_PATH`: path to a jmcomic option yaml.
- `JMCOMIC_SOURCE`: local source checkout to prefer over installed package, for example `D:\demo\workspace\JMComic-Crawler-Python\src`.
- `JM_VISUAL_DOWNLOAD_DIR`: album download directory.
- `JM_VISUAL_CACHE_DIR`: cover/image proxy cache directory.
