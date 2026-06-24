from __future__ import annotations

import os
import sys
import time
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path
from threading import Lock, RLock
from typing import Any, Literal

source_path = os.getenv("JMCOMIC_SOURCE")
if source_path:
    sys.path.insert(0, source_path)
else:
    for parent in Path(__file__).resolve().parents:
        local_checkout = parent / "JMComic-Crawler-Python" / "src"
        if local_checkout.exists():
            sys.path.insert(0, str(local_checkout))
            break

import jmcomic
from fastapi import BackgroundTasks, FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field


app = FastAPI(title="JM Visual API", version="0.1.0")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

ROOT_DIR = Path(__file__).resolve().parents[2]
DOWNLOAD_DIR = Path(os.getenv("JM_VISUAL_DOWNLOAD_DIR", ROOT_DIR / "downloads")).resolve()
CACHE_DIR = Path(os.getenv("JM_VISUAL_CACHE_DIR", ROOT_DIR / ".cache")).resolve()
IMAGE_CACHE_DIR = CACHE_DIR / "images"
COVER_CACHE_DIR = CACHE_DIR / "covers"

DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
IMAGE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
COVER_CACHE_DIR.mkdir(parents=True, exist_ok=True)

_client_lock = RLock()
_option = None
_client = None
_photo_cache: dict[str, Any] = {}
_album_cache: dict[str, Any] = {}
_executor = ThreadPoolExecutor(max_workers=int(os.getenv("JM_VISUAL_DOWNLOAD_WORKERS", "2")))


class DownloadRequest(BaseModel):
    id: str = Field(..., min_length=1)


@dataclass
class DownloadJob:
    id: str
    kind: Literal["album", "photo"]
    jm_id: str
    status: Literal["queued", "running", "done", "failed"] = "queued"
    message: str = ""
    total_images: int = 0
    completed_images: int = 0
    downloaded_bytes: int = 0
    speed_bps: float = 0
    output_paths: list[str] = field(default_factory=list)
    preview_images: list[str] = field(default_factory=list)
    created_at: float = field(default_factory=time.time)
    updated_at: float = field(default_factory=time.time)
    started_at: float | None = None
    finished_at: float | None = None


_jobs: dict[str, DownloadJob] = {}
_jobs_lock = Lock()


def _get_option():
    global _option
    with _client_lock:
        if _option is not None:
            return _option

        option_path = os.getenv("JM_OPTION_PATH")
        if option_path:
            _option = jmcomic.create_option_by_file(option_path)
        else:
            _option = jmcomic.JmOption.default()

        _option.dir_rule.base_dir = str(DOWNLOAD_DIR)
        return _option


def _get_client():
    global _client
    with _client_lock:
        if _client is None:
            _client = _get_option().new_jm_client(cache="level_option")
        return _client


def _cover_url(album_id: str) -> str:
    return f"/api/covers/{album_id}"


def _image_url(photo_id: str, index: int) -> str:
    return f"/api/photos/{photo_id}/images/{index}"


def _safe_list(value: Any) -> list[Any]:
    if value is None:
        return []
    if isinstance(value, list):
        return value
    if isinstance(value, tuple):
        return list(value)
    return [value]


def _page_to_dict(page: Any) -> dict[str, Any]:
    albums = []
    for aid, info in page.content:
        albums.append(
            {
                "id": str(aid),
                "title": str(info.get("name", "")),
                "author": info.get("author") or info.get("authors") or "",
                "tags": _safe_list(info.get("tags")),
                "coverUrl": _cover_url(str(aid)),
            }
        )

    return {
        "total": int(getattr(page, "total", len(albums)) or 0),
        "pageSize": int(getattr(page, "page_size", len(albums)) or len(albums) or 1),
        "pageCount": int(getattr(page, "page_count", 1) or 1),
        "albums": albums,
    }


def _album_to_dict(album: Any) -> dict[str, Any]:
    episodes = []
    for item in getattr(album, "episode_list", []) or []:
        photo_id, index, title = item
        episodes.append(
            {
                "id": str(photo_id),
                "index": int(index),
                "title": str(title).strip() or f"Chapter {index}",
            }
        )

    return {
        "id": str(getattr(album, "album_id", getattr(album, "id", ""))),
        "title": str(getattr(album, "name", "")),
        "authors": _safe_list(getattr(album, "authors", getattr(album, "author", []))),
        "tags": _safe_list(getattr(album, "tags", [])),
        "actors": _safe_list(getattr(album, "actors", [])),
        "works": _safe_list(getattr(album, "works", [])),
        "description": str(getattr(album, "description", "") or ""),
        "pageCount": int(getattr(album, "page_count", 0) or 0),
        "commentCount": str(getattr(album, "comment_count", "") or ""),
        "views": str(getattr(album, "views", "") or ""),
        "likes": str(getattr(album, "likes", "") or ""),
        "pubDate": str(getattr(album, "pub_date", "") or ""),
        "updateDate": str(getattr(album, "update_date", "") or ""),
        "coverUrl": _cover_url(str(getattr(album, "album_id", getattr(album, "id", "")))),
        "episodes": episodes,
    }


def _photo_to_dict(photo: Any) -> dict[str, Any]:
    images = []
    for index, image in enumerate(photo, start=1):
        images.append(
            {
                "index": index,
                "filename": getattr(image, "filename", f"{index}.jpg"),
                "url": _image_url(str(photo.photo_id), index),
            }
        )

    return {
        "id": str(getattr(photo, "photo_id", getattr(photo, "id", ""))),
        "albumId": str(getattr(photo, "album_id", "")),
        "title": str(getattr(photo, "name", "")),
        "imageCount": len(images),
        "images": images,
    }


def _get_album(album_id: str):
    album_id = jmcomic.JmcomicText.parse_to_jm_id(album_id)
    if album_id not in _album_cache:
        _album_cache[album_id] = _get_client().get_album_detail(album_id)
    return _album_cache[album_id]


def _get_photo(photo_id: str):
    photo_id = jmcomic.JmcomicText.parse_to_jm_id(photo_id)
    if photo_id not in _photo_cache:
        _photo_cache[photo_id] = _get_client().get_photo_detail(photo_id)
    return _photo_cache[photo_id]


def _job_to_dict(job: DownloadJob) -> dict[str, Any]:
    progress = 0 if job.total_images == 0 else min(1, job.completed_images / job.total_images)
    return {
        "id": job.id,
        "kind": job.kind,
        "jmId": job.jm_id,
        "status": job.status,
        "message": job.message,
        "progress": progress,
        "totalImages": job.total_images,
        "completedImages": job.completed_images,
        "downloadedBytes": job.downloaded_bytes,
        "speedBps": job.speed_bps,
        "outputPaths": job.output_paths,
        "previewImageCount": len(job.preview_images),
        "previewUrl": f"/api/downloads/{job.id}/preview" if job.preview_images else "",
        "createdAt": job.created_at,
        "updatedAt": job.updated_at,
        "startedAt": job.started_at,
        "finishedAt": job.finished_at,
    }


def _mark_job(job_id: str, **updates):
    with _jobs_lock:
        job = _jobs[job_id]
        for key, value in updates.items():
            setattr(job, key, value)
        job.updated_at = time.time()


def _touch_progress(job_id: str, image_path: str | None = None, completed_delta: int = 0, total_delta: int = 0):
    with _jobs_lock:
        job = _jobs[job_id]
        if total_delta:
            job.total_images += total_delta
        if completed_delta:
            job.completed_images += completed_delta
        if image_path:
            image_path = str(Path(image_path).resolve())
            if image_path not in job.preview_images:
                job.preview_images.append(image_path)
                try:
                    job.downloaded_bytes += Path(image_path).stat().st_size
                except OSError:
                    pass
        if job.started_at:
            elapsed = max(time.time() - job.started_at, 0.001)
            job.speed_bps = job.downloaded_bytes / elapsed
        job.updated_at = time.time()


def _append_output_path(job_id: str, path: str):
    resolved = str(Path(path).resolve())
    with _jobs_lock:
        job = _jobs[job_id]
        if resolved not in job.output_paths:
            job.output_paths.append(resolved)
        job.updated_at = time.time()


def _make_progress_downloader(job_id: str):
    class ProgressDownloader(jmcomic.JmDownloader):
        def __init__(self, option):
            super().__init__(option)
            self._seen_photos: set[str] = set()
            self._seen_images: set[str] = set()

        def before_album(self, album):
            _append_output_path(job_id, self.option.dir_rule.decide_album_root_dir(album))
            return super().before_album(album)

        def before_photo(self, photo):
            photo_key = str(photo.photo_id)
            if photo_key not in self._seen_photos:
                self._seen_photos.add(photo_key)
                _touch_progress(job_id, total_delta=len(photo))
            _append_output_path(job_id, self.option.decide_image_save_dir(photo))
            return super().before_photo(photo)

        def before_image(self, image, img_save_path):
            ret = super().before_image(image, img_save_path)
            key = f"{image.aid}:{image.index}:{img_save_path}"
            if key not in self._seen_images and image.cache and image.exists:
                self._seen_images.add(key)
                _touch_progress(job_id, img_save_path, completed_delta=1)
            return ret

        def after_image(self, image, img_save_path):
            ret = super().after_image(image, img_save_path)
            key = f"{image.aid}:{image.index}:{img_save_path}"
            if key not in self._seen_images:
                self._seen_images.add(key)
                _touch_progress(job_id, img_save_path, completed_delta=1)
            return ret

    return ProgressDownloader


def _run_job(job_id: str):
    _mark_job(job_id, status="running", started_at=time.time(), message="Preparing")
    try:
        with _jobs_lock:
            job = _jobs[job_id]
            kind = job.kind
            jm_id = job.jm_id

        option = _get_option().copy_option()
        option.dir_rule.base_dir = str(DOWNLOAD_DIR)
        downloader = _make_progress_downloader(job_id)
        func = jmcomic.download_album if kind == "album" else jmcomic.download_photo
        _mark_job(job_id, message="Downloading")
        func(jm_id, option, downloader=downloader)
        _mark_job(job_id, status="done", message="Completed", finished_at=time.time())
    except Exception as exc:  # noqa: BLE001 - surface jmcomic network/plugin failures to UI
        _mark_job(job_id, status="failed", message=str(exc), finished_at=time.time())


def _enqueue_download(kind: Literal["album", "photo"], jm_id: str, background_tasks: BackgroundTasks):
    job = DownloadJob(id=uuid.uuid4().hex, kind=kind, jm_id=jmcomic.JmcomicText.parse_to_jm_id(jm_id))
    with _jobs_lock:
        _jobs[job.id] = job

    background_tasks.add_task(_executor.submit, _run_job, job.id)
    return _job_to_dict(job)


@app.get("/health")
def health():
    return {
        "ok": True,
        "jmcomicVersion": jmcomic.__version__,
        "downloadDir": str(DOWNLOAD_DIR),
        "cacheDir": str(CACHE_DIR),
    }


@app.get("/api/albums/search")
def search_albums(
    query: str = Query("", description="JM search text"),
    page: int = Query(1, ge=1),
    search_type: Literal["site", "work", "author", "tag", "actor"] = "site",
    order_by: str = "mr",
    time_range: str = "a",
):
    client = _get_client()
    method_name = {
        "site": "search_site",
        "work": "search_work",
        "author": "search_author",
        "tag": "search_tag",
        "actor": "search_actor",
    }[search_type]
    method = getattr(client, method_name)
    return _page_to_dict(method(query, page=page, order_by=order_by, time=time_range))


@app.get("/api/albums/categories")
def categories(
    page: int = Query(1, ge=1),
    category: str = "0",
    order_by: str = "mr",
    time_range: str = "a",
):
    page_data = _get_client().categories_filter(
        page=page,
        time=time_range,
        category=category,
        order_by=order_by,
    )
    return _page_to_dict(page_data)


@app.get("/api/albums/ranking/{period}")
def ranking(period: Literal["day", "week", "month"], page: int = Query(1, ge=1), category: str = "0"):
    client = _get_client()
    method = {"day": client.day_ranking, "week": client.week_ranking, "month": client.month_ranking}[period]
    return _page_to_dict(method(page, category=category))


@app.get("/api/albums/{album_id}")
def album_detail(album_id: str):
    try:
        return _album_to_dict(_get_album(album_id))
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.get("/api/photos/{photo_id}")
def photo_detail(photo_id: str):
    try:
        return _photo_to_dict(_get_photo(photo_id))
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=str(exc)) from exc


@app.get("/api/covers/{album_id}")
def cover(album_id: str):
    album_id = jmcomic.JmcomicText.parse_to_jm_id(album_id)
    cover_path = COVER_CACHE_DIR / f"{album_id}.jpg"
    if not cover_path.exists():
        try:
            _get_client().download_album_cover(album_id, str(cover_path))
        except Exception as exc:  # noqa: BLE001
            raise HTTPException(status_code=502, detail=str(exc)) from exc
    return FileResponse(cover_path)


@app.get("/api/photos/{photo_id}/images/{index}")
def photo_image(photo_id: str, index: int):
    photo = _get_photo(photo_id)
    if index < 1 or index > len(photo):
        raise HTTPException(status_code=404, detail="Image index out of range")

    image = photo[index - 1]
    suffix = getattr(image, "img_file_suffix", ".jpg") or ".jpg"
    image_path = IMAGE_CACHE_DIR / str(photo.photo_id) / f"{index:05d}{suffix}"
    image_path.parent.mkdir(parents=True, exist_ok=True)

    if not image_path.exists():
        try:
            _get_client().download_by_image_detail(image, str(image_path), decode_image=True)
        except Exception as exc:  # noqa: BLE001
            raise HTTPException(status_code=502, detail=str(exc)) from exc

    return FileResponse(image_path)


@app.post("/api/downloads/albums")
def download_album(req: DownloadRequest, background_tasks: BackgroundTasks):
    return _enqueue_download("album", req.id, background_tasks)


@app.post("/api/downloads/photos")
def download_photo(req: DownloadRequest, background_tasks: BackgroundTasks):
    return _enqueue_download("photo", req.id, background_tasks)


@app.get("/api/downloads")
def downloads():
    with _jobs_lock:
        jobs = sorted(_jobs.values(), key=lambda item: item.created_at, reverse=True)
        return {"jobs": [_job_to_dict(job) for job in jobs]}


@app.get("/api/downloads/{job_id}/preview")
def download_preview(job_id: str):
    with _jobs_lock:
        job = _jobs.get(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail="Download job not found")
        images = list(job.preview_images)

    return {
        "id": job_id,
        "albumId": job.jm_id if job.kind == "album" else "",
        "title": f"{'Album' if job.kind == 'album' else 'Photo'} JM{job.jm_id}",
        "imageCount": len(images),
        "images": [
            {
                "index": index + 1,
                "filename": Path(path).name,
                "url": f"/api/downloads/{job_id}/files/{index + 1}",
            }
            for index, path in enumerate(images)
        ],
    }


@app.get("/api/downloads/{job_id}/files/{index}")
def download_preview_file(job_id: str, index: int):
    with _jobs_lock:
        job = _jobs.get(job_id)
        if job is None:
            raise HTTPException(status_code=404, detail="Download job not found")
        if index < 1 or index > len(job.preview_images):
            raise HTTPException(status_code=404, detail="Preview image index out of range")
        file_path = Path(job.preview_images[index - 1]).resolve()

    try:
        file_path.relative_to(DOWNLOAD_DIR)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail="Preview file is outside download directory") from exc

    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Preview image no longer exists")

    return FileResponse(file_path)


WEB_DIR = os.getenv("JM_VISUAL_WEB_DIR")
if WEB_DIR and Path(WEB_DIR).exists():
    app.mount("/", StaticFiles(directory=WEB_DIR, html=True), name="web")
