# ---- backend image -------------------------------------------------------
# python:3.12-slim, not :latest and not plain :3.12.
#   pinned tag  -> a rebuild next month produces the same base, so a broken
#                  build is caused by YOUR change, not a surprise upstream one
#   -slim       -> ~80MB instead of ~1GB; smaller image = faster pod starts
#                  and a smaller CVE surface to patch
FROM python:3.12-slim

# PYTHONDONTWRITEBYTECODE: no .pyc files -- the container is thrown away, so
#   writing them only dirties the filesystem layer.
# PYTHONUNBUFFERED: print() reaches stdout immediately. Without it, Python
#   buffers output and `kubectl logs` shows NOTHING until the buffer flushes
#   or the pod dies. This one line saves hours of "why are there no logs".
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

WORKDIR /app

# Copy requirements.txt ALONE first, install, and only then copy the source.
# WHY: Docker caches each layer and invalidates every layer after the first
# changed one. Code changes far more often than dependencies, so this order
# means a one-line code edit reuses the cached pip install instead of
# re-downloading everything.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app

# Run as a non-root user. A container process is root ON THE HOST kernel by
# default; if the app is compromised, that is a much better starting point for
# an attacker than an unprivileged uid. EKS Pod Security Standards will also
# reject root containers under the "restricted" profile.
RUN useradd --create-home --uid 10001 appuser \
    && chown -R appuser:appuser /app
USER appuser

EXPOSE 8000

# --host 0.0.0.0, NOT 127.0.0.1. Inside a container, 127.0.0.1 means "this
# container only" -- Kubernetes could never reach it and every request would
# time out. This is the single most common containerisation mistake.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
