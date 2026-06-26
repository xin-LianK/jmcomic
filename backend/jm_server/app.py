from __future__ import annotations

import os
import sys
import time
import uuid
import json
import re
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from threading import Event, Lock, RLock, Thread
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
from fastapi import FastAPI, HTTPException, Query
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
SETTINGS_PATH = CACHE_DIR / "settings.json"
WATCHLIST_PATH = CACHE_DIR / "watchlist.json"

DOWNLOAD_DIR.mkdir(parents=True, exist_ok=True)
IMAGE_CACHE_DIR.mkdir(parents=True, exist_ok=True)
COVER_CACHE_DIR.mkdir(parents=True, exist_ok=True)

_client_lock = RLock()
_option = None
_client = None
_photo_cache: dict[str, Any] = {}
_album_cache: dict[str, Any] = {}
_executor = ThreadPoolExecutor(max_workers=int(os.getenv("JM_VISUAL_DOWNLOAD_WORKERS", "2")))
_settings_lock = RLock()
_watchlist_lock = RLock()
_watch_stop = Event()
_watch_thread: Thread | None = None

_DOWNLOAD_DIR_RULE = os.getenv("JM_VISUAL_DIR_RULE", "Bd/Aidoname/Pindextitle")
_DEFAULT_SETTINGS = {
    "barkUrls": [],
    "watchIntervalMinutes": int(os.getenv("JM_VISUAL_WATCH_INTERVAL_MINUTES", "60")),
}
_WEEKDAYS = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]


class DownloadRequest(BaseModel):
    id: str = Field(..., min_length=1)
    albumId: str = ""
    albumTitle: str = ""
    episodeTitle: str = ""
    episodeIndex: int = 0


class VisualSettingsRequest(BaseModel):
    barkUrls: list[str] = Field(default_factory=list)
    watchIntervalMinutes: int = Field(default=60, ge=5, le=10080)


class WatchAlbumRequest(BaseModel):
    id: str = Field(..., min_length=1)
    title: str = ""
    coverUrl: str = ""
    enabled: bool = True
    knownEpisodeIds: list[str] = Field(default_factory=list)


@dataclass
class DownloadChapter:
    id: str
    index: int = 0
    title: str = ""
    status: Literal["queued", "running", "done", "failed"] = "queued"
    total_images: int = 0
    completed_images: int = 0
    downloaded_bytes: int = 0
    output_path: str = ""
    file_size: int = 0


@dataclass
class DownloadJob:
    id: str
    kind: Literal["album", "photo"]
    jm_id: str
    album_id: str = ""
    album_title: str = ""
    episode_title: str = ""
    episode_index: int = 0
    status: Literal["queued", "running", "done", "failed"] = "queued"
    message: str = ""
    total_images: int = 0
    completed_images: int = 0
    downloaded_bytes: int = 0
    speed_bps: float = 0
    output_paths: list[str] = field(default_factory=list)
    preview_images: list[str] = field(default_factory=list)
    chapters: dict[str, DownloadChapter] = field(default_factory=dict)
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

        _apply_download_dir_rule(_option)
        return _option


def _apply_download_dir_rule(option):
    normalize_zh = getattr(getattr(option, "dir_rule", None), "normalize_zh", None)
    option.dir_rule = jmcomic.DirRule(
        rule=_DOWNLOAD_DIR_RULE,
        base_dir=str(DOWNLOAD_DIR),
        normalize_zh=normalize_zh,
    )


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


def _read_json(path: Path, default: dict[str, Any]) -> dict[str, Any]:
    if not path.exists():
        return dict(default)
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        return data if isinstance(data, dict) else dict(default)
    except Exception:
        return dict(default)


def _write_json(path: Path, data: dict[str, Any]):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def _load_settings() -> dict[str, Any]:
    with _settings_lock:
        data = _read_json(SETTINGS_PATH, _DEFAULT_SETTINGS)
        urls = data.get("barkUrls") or []
        if isinstance(urls, str):
            urls = re.split(r"[\n,]+", urls)
        data["barkUrls"] = [str(url).strip() for url in urls if str(url).strip()]
        data["watchIntervalMinutes"] = max(5, int(data.get("watchIntervalMinutes") or 60))
        return data


def _save_settings(data: dict[str, Any]) -> dict[str, Any]:
    cleaned = {
        "barkUrls": [str(url).strip() for url in data.get("barkUrls", []) if str(url).strip()],
        "watchIntervalMinutes": max(5, int(data.get("watchIntervalMinutes") or 60)),
    }
    with _settings_lock:
        _write_json(SETTINGS_PATH, cleaned)
    return cleaned


def _load_watchlist() -> dict[str, Any]:
    with _watchlist_lock:
        data = _read_json(WATCHLIST_PATH, {"albums": {}})
        if not isinstance(data.get("albums"), dict):
            data["albums"] = {}
        return data


def _save_watchlist(data: dict[str, Any]) -> dict[str, Any]:
    with _watchlist_lock:
        _write_json(WATCHLIST_PATH, data)
    return data


def _weekday_from_date(value: str) -> str:
    text = (value or "").strip()
    if not text:
        return ""
    match = re.search(r"(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})", text)
    if match is None:
        return ""
    try:
        date = datetime(int(match.group(1)), int(match.group(2)), int(match.group(3)))
    except ValueError:
        return ""
    return _WEEKDAYS[date.weekday()]


def _first_text(mapping: dict[str, Any], *keys: str) -> str:
    for key in keys:
        value = mapping.get(key)
        if value not in (None, ""):
            return str(value)
    return ""


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
        update_date = _first_text(
            info,
            "update_date",
            "updateDate",
            "latest_update",
            "latestUpdate",
            "date",
            "time",
        )
        albums.append(
            {
                "id": str(aid),
                "title": str(info.get("name", "")),
                "author": info.get("author") or info.get("authors") or "",
                "tags": _safe_list(info.get("tags")),
                "coverUrl": _cover_url(str(aid)),
                "updateDate": update_date,
                "updateWeekday": _weekday_from_date(update_date),
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
        photo_id = item[0]
        index = item[1]
        title = item[2] if len(item) >= 3 else ""
        pub_date = item[3] if len(item) >= 4 else ""
        episodes.append(
            {
                "id": str(photo_id),
                "index": int(index),
                "title": str(title).strip() or f"Chapter {index}",
                "pubDate": str(pub_date or ""),
                "fileSize": 0,
            }
        )

    update_date = str(getattr(album, "update_date", "") or "")
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
        "updateDate": update_date,
        "updateWeekday": _weekday_from_date(update_date),
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


def _get_album(album_id: str, force_refresh: bool = False):
    album_id = jmcomic.JmcomicText.parse_to_jm_id(album_id)
    if force_refresh or album_id not in _album_cache:
        _album_cache[album_id] = _get_client().get_album_detail(album_id)
    return _album_cache[album_id]


def _get_photo(photo_id: str):
    photo_id = jmcomic.JmcomicText.parse_to_jm_id(photo_id)
    if photo_id not in _photo_cache:
        _photo_cache[photo_id] = _get_client().get_photo_detail(photo_id)
    return _photo_cache[photo_id]


def _chapter_to_dict(chapter: DownloadChapter) -> dict[str, Any]:
    return {
        "id": chapter.id,
        "index": chapter.index,
        "title": chapter.title,
        "status": chapter.status,
        "totalImages": chapter.total_images,
        "completedImages": chapter.completed_images,
        "downloadedBytes": chapter.downloaded_bytes,
        "outputPath": chapter.output_path,
        "fileSize": chapter.file_size,
    }


def _job_to_dict(job: DownloadJob) -> dict[str, Any]:
    progress = 0 if job.total_images == 0 else min(1, job.completed_images / job.total_images)
    chapters = sorted(job.chapters.values(), key=lambda item: (item.index or 999999, item.id))
    return {
        "id": job.id,
        "kind": job.kind,
        "jmId": job.jm_id,
        "albumId": job.album_id or job.jm_id,
        "albumTitle": job.album_title,
        "episodeTitle": job.episode_title,
        "episodeIndex": job.episode_index,
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
        "chapters": [_chapter_to_dict(chapter) for chapter in chapters],
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


def _ensure_chapter(job: DownloadJob, chapter_id: str) -> DownloadChapter:
    chapter = job.chapters.get(chapter_id)
    if chapter is None:
        chapter = DownloadChapter(id=chapter_id)
        job.chapters[chapter_id] = chapter
    return chapter


def _mark_chapter(job_id: str, chapter_id: str, **updates):
    with _jobs_lock:
        job = _jobs[job_id]
        chapter = _ensure_chapter(job, chapter_id)
        for key, value in updates.items():
            setattr(chapter, key, value)
        job.updated_at = time.time()


def _touch_progress(
    job_id: str,
    image_path: str | None = None,
    completed_delta: int = 0,
    total_delta: int = 0,
    chapter_id: str | None = None,
):
    with _jobs_lock:
        job = _jobs[job_id]
        if total_delta:
            job.total_images += total_delta
        if completed_delta:
            job.completed_images += completed_delta
        chapter: DownloadChapter | None = None
        if chapter_id:
            chapter = _ensure_chapter(job, chapter_id)
            if total_delta:
                chapter.total_images += total_delta
            if completed_delta:
                chapter.completed_images += completed_delta
        if image_path:
            image_path = str(Path(image_path).resolve())
            if image_path not in job.preview_images:
                job.preview_images.append(image_path)
                try:
                    size = Path(image_path).stat().st_size
                    job.downloaded_bytes += size
                    if chapter is not None:
                        chapter.downloaded_bytes += size
                        chapter.file_size += size
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
            episodes = {}
            for item in getattr(album, "episode_list", []) or []:
                photo_id = str(item[0])
                episodes[photo_id] = DownloadChapter(
                    id=photo_id,
                    index=int(item[1]),
                    title=str(item[2] if len(item) >= 3 else "").strip(),
                )
            _mark_job(
                job_id,
                album_id=str(getattr(album, "album_id", getattr(album, "id", ""))),
                album_title=str(getattr(album, "name", "") or ""),
                chapters=episodes,
            )
            return super().before_album(album)

        def before_photo(self, photo):
            photo_key = str(photo.photo_id)
            if photo_key not in self._seen_photos:
                self._seen_photos.add(photo_key)
                _touch_progress(job_id, total_delta=len(photo), chapter_id=photo_key)
            output_path = self.option.decide_image_save_dir(photo)
            _append_output_path(job_id, output_path)
            _mark_chapter(
                job_id,
                photo_key,
                index=int(getattr(photo, "album_index", getattr(photo, "index", 0)) or 0),
                title=str(getattr(photo, "name", "") or ""),
                status="running",
                output_path=str(Path(output_path).resolve()),
            )
            _mark_job(
                job_id,
                album_id=str(getattr(photo, "album_id", "") or ""),
                episode_title=str(getattr(photo, "name", "") or ""),
                episode_index=int(getattr(photo, "album_index", getattr(photo, "index", 0)) or 0),
            )
            return super().before_photo(photo)

        def after_photo(self, photo):
            ret = super().after_photo(photo)
            _mark_chapter(job_id, str(photo.photo_id), status="done")
            return ret

        def before_image(self, image, img_save_path):
            ret = super().before_image(image, img_save_path)
            key = f"{image.aid}:{image.index}:{img_save_path}"
            if key not in self._seen_images and image.cache and image.exists:
                self._seen_images.add(key)
                _touch_progress(job_id, img_save_path, completed_delta=1, chapter_id=str(image.aid))
            return ret

        def after_image(self, image, img_save_path):
            ret = super().after_image(image, img_save_path)
            key = f"{image.aid}:{image.index}:{img_save_path}"
            if key not in self._seen_images:
                self._seen_images.add(key)
                _touch_progress(job_id, img_save_path, completed_delta=1, chapter_id=str(image.aid))
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
        _apply_download_dir_rule(option)
        downloader = _make_progress_downloader(job_id)
        func = jmcomic.download_album if kind == "album" else jmcomic.download_photo
        _mark_job(job_id, message="Downloading")
        func(jm_id, option, downloader=downloader)
        _mark_job(job_id, status="done", message="Completed", finished_at=time.time())
    except Exception as exc:  # noqa: BLE001 - surface jmcomic network/plugin failures to UI
        with _jobs_lock:
            job = _jobs.get(job_id)
            if job is not None:
                for chapter in job.chapters.values():
                    if chapter.status in {"queued", "running"}:
                        chapter.status = "failed"
        _mark_job(job_id, status="failed", message=str(exc), finished_at=time.time())


def _seed_job_metadata(job: DownloadJob, req: DownloadRequest | None = None):
    if req is not None:
        job.album_id = req.albumId or job.album_id
        job.album_title = req.albumTitle or job.album_title
        job.episode_title = req.episodeTitle or job.episode_title
        job.episode_index = req.episodeIndex or job.episode_index

    try:
        if job.kind == "album":
            album = _get_album(job.jm_id)
            job.album_id = str(getattr(album, "album_id", getattr(album, "id", job.jm_id)))
            job.album_title = job.album_title or str(getattr(album, "name", "") or "")
            for item in getattr(album, "episode_list", []) or []:
                photo_id = str(item[0])
                job.chapters[photo_id] = DownloadChapter(
                    id=photo_id,
                    index=int(item[1]),
                    title=str(item[2] if len(item) >= 3 else "").strip(),
                )
        else:
            photo = _get_photo(job.jm_id)
            job.album_id = job.album_id or str(getattr(photo, "album_id", "") or job.jm_id)
            job.episode_title = job.episode_title or str(getattr(photo, "name", "") or "")
            job.episode_index = job.episode_index or int(
                getattr(photo, "album_index", getattr(photo, "index", 0)) or 0
            )
            if not job.album_title and getattr(photo, "from_album", None) is not None:
                job.album_title = str(getattr(photo.from_album, "name", "") or "")
            job.chapters[job.jm_id] = DownloadChapter(
                id=job.jm_id,
                index=job.episode_index,
                title=job.episode_title,
            )
    except Exception:
        # Metadata makes the UI nicer, but download itself can still be attempted.
        pass


def _enqueue_download(
    kind: Literal["album", "photo"],
    jm_id: str,
    req: DownloadRequest | None = None,
):
    parsed_id = jmcomic.JmcomicText.parse_to_jm_id(jm_id)
    album_id = parsed_id
    if kind == "photo":
        album_id = req.albumId if req is not None and req.albumId else parsed_id
    job = DownloadJob(id=uuid.uuid4().hex, kind=kind, jm_id=parsed_id, album_id=album_id)
    _seed_job_metadata(job, req)
    with _jobs_lock:
        _jobs[job.id] = job

    _executor.submit(_run_job, job.id)
    return _job_to_dict(job)


def _episode_ids(album: Any) -> list[str]:
    return [str(item[0]) for item in getattr(album, "episode_list", []) or []]


def _upsert_watched_album(req: WatchAlbumRequest) -> dict[str, Any]:
    album_id = jmcomic.JmcomicText.parse_to_jm_id(req.id)
    now = time.time()
    known_ids = [jmcomic.JmcomicText.parse_to_jm_id(item) for item in req.knownEpisodeIds if str(item).strip()]
    update_date = ""
    update_weekday = ""
    title = req.title
    cover_url = req.coverUrl or _cover_url(album_id)

    if req.enabled and not known_ids:
        album = _get_album(album_id, force_refresh=True)
        known_ids = _episode_ids(album)
        title = title or str(getattr(album, "name", "") or "")
        update_date = str(getattr(album, "update_date", "") or "")
        update_weekday = _weekday_from_date(update_date)

    data = _load_watchlist()
    current = data["albums"].get(album_id, {})
    item = {
        **current,
        "id": album_id,
        "title": title or current.get("title", ""),
        "coverUrl": cover_url or current.get("coverUrl", ""),
        "enabled": req.enabled,
        "knownEpisodeIds": known_ids or current.get("knownEpisodeIds", []),
        "updateDate": update_date or current.get("updateDate", ""),
        "updateWeekday": update_weekday or current.get("updateWeekday", ""),
        "lastCheckedAt": current.get("lastCheckedAt", 0),
        "updatedAt": now,
    }
    data["albums"][album_id] = item
    _save_watchlist(data)
    return item


def _build_bark_url(raw_url: str, title: str, body: str) -> str:
    if "{title}" in raw_url or "{body}" in raw_url:
        return raw_url.format(
            title=urllib.parse.quote(title, safe=""),
            body=urllib.parse.quote(body, safe=""),
        )

    parts = urllib.parse.urlsplit(raw_url.strip())
    path = parts.path.rstrip("/")
    path = f"{path}/{urllib.parse.quote(title, safe='')}/{urllib.parse.quote(body, safe='')}"
    query = dict(urllib.parse.parse_qsl(parts.query, keep_blank_values=True))
    query.setdefault("group", "JM Visual")
    return urllib.parse.urlunsplit(
        (parts.scheme, parts.netloc, path, urllib.parse.urlencode(query), parts.fragment)
    )


def _send_bark_notification(title: str, body: str):
    urls = _load_settings().get("barkUrls", [])
    for raw_url in urls:
        try:
            url = _build_bark_url(raw_url, title, body)
            with urllib.request.urlopen(url, timeout=8) as response:  # noqa: S310 - user-configured Bark URL
                response.read(64)
        except Exception as exc:  # noqa: BLE001
            print(f"[watch] Bark notification failed: {exc}", file=sys.stderr)


def _check_watched_album(album_id: str, item: dict[str, Any]):
    now = time.time()
    known_ids = {str(value) for value in item.get("knownEpisodeIds", [])}
    album = _get_album(album_id, force_refresh=True)
    album_dict = _album_to_dict(album)
    episodes = album_dict["episodes"]
    current_ids = {episode["id"] for episode in episodes}
    new_episodes = [episode for episode in episodes if episode["id"] not in known_ids]

    data = _load_watchlist()
    saved = data["albums"].get(album_id, item)
    saved["title"] = album_dict["title"] or saved.get("title", "")
    saved["coverUrl"] = album_dict["coverUrl"] or saved.get("coverUrl", "")
    saved["knownEpisodeIds"] = sorted(
        current_ids,
        key=lambda value: (0, int(value)) if value.isdigit() else (1, value),
    )
    saved["updateDate"] = album_dict.get("updateDate", "")
    saved["updateWeekday"] = album_dict.get("updateWeekday", "")
    saved["lastCheckedAt"] = now
    saved["updatedAt"] = now
    data["albums"][album_id] = saved
    _save_watchlist(data)

    if not known_ids or not new_episodes:
        return

    for episode in new_episodes:
        req = DownloadRequest(
            id=episode["id"],
            albumId=album_dict["id"],
            albumTitle=album_dict["title"],
            episodeTitle=episode["title"],
            episodeIndex=episode["index"],
        )
        _enqueue_download("photo", episode["id"], req=req)

    title = f"{album_dict['title'] or 'JM' + album_id} 更新了"
    names = "、".join(episode["title"] or f"第 {episode['index']} 话" for episode in new_episodes[:3])
    extra = "" if len(new_episodes) <= 3 else f" 等 {len(new_episodes)} 章"
    _send_bark_notification(title, f"发现新章节：{names}{extra}，已加入服务器下载队列。")


def _run_watch_checks():
    settings = _load_settings()
    interval = max(5, int(settings.get("watchIntervalMinutes") or 60)) * 60
    now = time.time()
    data = _load_watchlist()
    albums = list(data.get("albums", {}).items())
    for album_id, item in albums:
        if not item.get("enabled", False):
            continue
        if now - float(item.get("lastCheckedAt") or 0) < interval:
            continue
        try:
            _check_watched_album(album_id, item)
        except Exception as exc:  # noqa: BLE001
            print(f"[watch] Failed checking JM{album_id}: {exc}", file=sys.stderr)


def _watch_loop():
    while not _watch_stop.is_set():
        _run_watch_checks()
        _watch_stop.wait(60)


@app.on_event("startup")
def _start_watch_thread():
    global _watch_thread
    if _watch_thread is not None:
        return
    _watch_thread = Thread(target=_watch_loop, name="jm-visual-watch", daemon=True)
    _watch_thread.start()


@app.on_event("shutdown")
def _stop_watch_thread():
    _watch_stop.set()


@app.get("/health")
def health():
    return {
        "ok": True,
        "jmcomicVersion": jmcomic.__version__,
        "downloadDir": str(DOWNLOAD_DIR),
        "cacheDir": str(CACHE_DIR),
        "dirRule": _DOWNLOAD_DIR_RULE,
    }


@app.get("/api/settings")
def visual_settings():
    return _load_settings()


@app.put("/api/settings")
def update_visual_settings(req: VisualSettingsRequest):
    return _save_settings(req.model_dump() if hasattr(req, "model_dump") else req.dict())


@app.get("/api/watchlist")
def watchlist():
    data = _load_watchlist()
    albums = sorted(
        data.get("albums", {}).values(),
        key=lambda item: float(item.get("updatedAt") or 0),
        reverse=True,
    )
    return {"albums": albums}


@app.put("/api/watchlist/{album_id}")
def set_watched_album(album_id: str, req: WatchAlbumRequest):
    if jmcomic.JmcomicText.parse_to_jm_id(req.id) != jmcomic.JmcomicText.parse_to_jm_id(album_id):
        raise HTTPException(status_code=400, detail="Album id mismatch")
    return _upsert_watched_album(req)


@app.post("/api/watchlist/{album_id}/check")
def check_watched_album(album_id: str):
    data = _load_watchlist()
    parsed_id = jmcomic.JmcomicText.parse_to_jm_id(album_id)
    item = data.get("albums", {}).get(parsed_id)
    if item is None:
        raise HTTPException(status_code=404, detail="Watched album not found")
    _check_watched_album(parsed_id, item)
    return _load_watchlist()["albums"][parsed_id]


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
def download_album(req: DownloadRequest):
    return _enqueue_download("album", req.id, req=req)


@app.post("/api/downloads/photos")
def download_photo(req: DownloadRequest):
    return _enqueue_download("photo", req.id, req=req)


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
