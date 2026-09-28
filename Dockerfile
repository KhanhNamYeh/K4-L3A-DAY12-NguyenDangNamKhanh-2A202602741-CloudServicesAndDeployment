# ═══════════════════════════════════════════════════════════════════
# CP2 — Containerization (production-ready)
#
#   [x] Multi-stage build: `builder` cài dependency vào /install, stage
#       runtime chỉ copy kết quả sang → không mang theo pip cache/compiler
#   [x] Base image python:3.11-slim cho cả hai stage
#   [x] COPY requirements.txt + pip install TRƯỚC khi COPY source code
#   [x] Chạy bằng user thường `appuser` (uid 10001), không phải root
#   [x] HEALTHCHECK gọi /health
#   [x] Đọc cổng từ biến môi trường PORT (mặc định 8000)
#
# Kiểm tra:  pytest tests/test_cp2.py -v
# Build thử: docker build -t day12-agent:prod .
#            docker images day12-agent:prod     # xem dung lượng
# ═══════════════════════════════════════════════════════════════════

# ─── Stage 1: builder — cài dependency, stage này bị vứt đi sau build ───
FROM python:3.11-slim AS builder

WORKDIR /build

# Chỉ copy requirements.txt để layer pip install được cache: sửa code
# không làm cài lại thư viện.
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt


# ─── Stage 2: runtime — chỉ chứa Python + thư viện đã cài + source ───
FROM python:3.11-slim AS runtime

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

# User thường, không có quyền root
RUN useradd --create-home --uid 10001 appuser

WORKDIR /app

COPY --from=builder /install /usr/local

# Source code copy SAU cùng — layer thay đổi thường xuyên nhất
COPY --chown=appuser:appuser app ./app
COPY --chown=appuser:appuser utils ./utils

USER appuser

EXPOSE 8000

# urlopen raise lỗi khi không kết nối được hoặc nhận 4xx/5xx (vd 503 lúc
# shutting_down) → exit 1 → container bị đánh dấu unhealthy.
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:${PORT:-8000}/health', timeout=4)" || exit 1

# Dạng shell (sh -c) để ${PORT} được thay lúc container chạy; `exec` để
# uvicorn là PID 1 và nhận SIGTERM trực tiếp từ orchestrator.
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
