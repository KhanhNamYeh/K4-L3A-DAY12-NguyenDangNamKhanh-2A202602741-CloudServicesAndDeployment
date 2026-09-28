# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Nguyen Dang Nam Khanh |
| Mã học viên | 2A202602741 |
| Repo | https://github.com/KhanhNamYeh/K4-L3A-DAY12-NguyenDangNamKhanh-2A202602741-CloudServicesAndDeployment |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | Không có — dùng phương án dự phòng, service chạy ở `http://localhost:8000` |
| Platform | Local fallback: `docker compose` trên máy cá nhân (không deploy lên Railway / Render / Cloud Run) |
| Ngày chạy | 2026-09-28 |

## Biến Môi Trường Đã Set

Chạy bằng `docker compose` nên biến môi trường đến từ `docker-compose.yml` và
file `.env` ở máy (không commit). Chỉ ghi tên và nguồn, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | mặc định 8000 trong Dockerfile (`ENV PORT=8000`) |
| `AGENT_API_KEY` | ✅ | nội suy `${AGENT_API_KEY}` từ `.env` cục bộ, không nằm trong repo |
| `REDIS_URL` | ✅ | `redis://redis:6379/0` — service `redis` (redis:7-alpine) trong cùng compose |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Với phương án dự phòng, `<URL>` là `http://localhost:8000`:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

> Trên Windows (Git Bash), câu hỏi có dấu truyền thẳng qua `-d` bị hỏng mã
> hóa trước khi tới server (`There was an error parsing the body`). Lệnh 4 được
> chạy bằng `--data-binary @q.json` với file UTF-8 chứa cùng nội dung.

## Kết Quả Chạy Thật

Output chạy ngày 2026-09-28 với `URL=http://localhost:8000`:

```
$ curl -i $URL/health
HTTP/1.1 200 OK
date: Mon, 28 Sep 2026 14:15:38 GMT
server: uvicorn
content-length: 57
content-type: application/json

{"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl -i $URL/ready
HTTP/1.1 200 OK
date: Mon, 28 Sep 2026 14:15:38 GMT
server: uvicorn
content-length: 31
content-type: application/json

{"status":"ready","redis":true}

$ curl -i -X POST $URL/ask  (không có API key)
HTTP/1.1 401 Unauthorized
date: Mon, 28 Sep 2026 14:15:38 GMT
server: uvicorn
content-length: 39
content-type: application/json

{"detail":"invalid or missing API key"}

$ curl -i -X POST $URL/ask -H "X-API-Key: $AGENT_API_KEY" -H "X-User-Id: sv-test"  (question: "Deploy là gì?")
HTTP/1.1 200 OK
date: Mon, 28 Sep 2026 14:15:38 GMT
server: uvicorn
content-length: 279
content-type: application/json

{"answer":"Câu hỏi hay. Deploy là gì thường được giải quyết bằng cách chuẩn hóa môi trường chạy: cùng một image chạy giống nhau ở laptop và trên cloud.","user_id":"sv-test","history_length":0,"cost_usd":2.145e-05,"tokens":{"in":3,"out":35}}

$ for i in $(seq 1 15); do curl ... /ask; done   (rate limit, cùng user sv-test)
200 200 200 200 200 200 200 200 200 429 429 429 429 429 429
```

Vòng lặp chỉ có 9 lần 200 vì lệnh 4 ngay trước đó đã dùng 1 trong 10
request/phút của `sv-test` trong cùng cửa sổ 60 giây.

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/compose-ps.png` — terminal chạy `docker compose ps` (agent + redis healthy)
- `screenshots/health.png` — kết quả gọi `/health` từ trình duyệt hoặc curl

---

## Phương Án Dự Phòng

Bài dùng `LOCAL_FALLBACK=true`: stack `agent` + `redis` chạy bằng
`docker compose up -d` ở máy cá nhân, `pytest tests/test_cp5.py` kiểm tra
`http://localhost:8000`.

```
Lý do không deploy lên cloud: học viên chọn phương án dự phòng, không tạo
service trên Railway/Render.
```
