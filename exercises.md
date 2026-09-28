# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng `> *Câu trả lời của bạn*` bằng câu trả lời.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyen Dang Nam Khanh  Mã học viên: 2A202602741

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Khi deploy lên cloud mà quên set biến `AGENT_API_KEY`, ứng dụng crash ngay lập tức (`ValidationError`), giúp phát hiện lỗi trên log deploy. Nếu để mặc định `"changeme"`, service vẫn chạy nhưng gọi API sẽ lỗi ngầm, đồng thời lộ khóa trên repo public.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

* Dòng log:

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T09:04:26.101085+00:00", "user_id": "sv-cp4", "tokens_in": 392, "tokens_out": 43, "cost_usd": 8.46e-05}
```

* Hai việc làm được:
  1. Lọc và tính tổng chi phí `cost_usd` theo `user_id`.
  2. Tự động bắn cảnh báo khi số lượng `level == "error"` tăng đột biến.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1.73 GB |
| Multi-stage | 274 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

* Chênh lệch là do: Bản đầy đủ dùng base image `python:3.11` (1.61 GB) chứa compiler, header không cần thiết lúc chạy, trong khi bản multi-stage dùng `python:3.11-slim` (189 MB). Ngoài ra, bản 1 stage còn dính pip cache và toàn bộ test, tài liệu do `COPY . .`.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

* **Sửa 1 ký tự trong `app/main.py`:**
  * Dùng lại cache: `WORKDIR`, `COPY requirements.txt`, `RUN pip install`, `useradd`, `COPY --from=builder`.
  * Phải chạy lại: Chỉ `COPY app` và `COPY utils` (mất 0.0s).
* **Nếu đặt `COPY . .` trước `RUN pip install`:** Mã nguồn thay đổi làm mất cache của layer `COPY`, buộc pip phải tải và cài lại toàn bộ thư viện từ đầu, tốn nhiều thời gian và dễ bị timeout PyPI.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

* **Chuỗi sự kiện:** Lỗ hổng code (RCE) $ightarrow$ Kẻ tấn công chạy lệnh với quyền tiến trình trong container $ightarrow$ Nếu là `root`, kẻ tấn công can thiệp sâu hệ thống file, cài công cụ rồi lợi dụng kernel exploit hoặc volume mount để thoát container, chiếm quyền root máy host.
* **Lệnh `USER`:** Cắt đứt chuỗi ngay ở bước thứ hai vì kẻ tấn công chỉ có quyền user thường (UID 10001), không thể can thiệp hệ thống hay leo thang đặc quyền ra host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

* Gửi tối đa **20 request** trong 2 giây liên tiếp.
* **Giải thích:** Gửi 10 request lúc 10:00:59 (hết quota phút trước) và 10 request lúc 10:01:00 (bộ đếm reset sang phút mới). Với sliding window, 10 request lúc :59 vẫn nằm trong khung 60 giây nên các request lúc :00 sẽ bị chặn ngay.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

* **Khác nhau:** Rate limit đếm số request/phút (trả về 429); cost guard đếm tổng tiền/tháng (trả về 402).
* **Rate limit cho qua, cost guard chặn:** User gửi ít request nhưng mỗi câu hỏi dài hàng chục nghìn token (tiền vọt lên cao dù request ít).
* **Cost guard cho qua, rate limit chặn:** Gửi dồn dập 15 request cực ngắn trong 1 phút; chi phí gần như bằng 0 nhưng từ request thứ 11 sẽ bị 429.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

1. Redis mất kết nối trong 30 giây.
2. Endpoint gộp kiểm tra cả Redis nên cả 3 container đồng loạt báo unhealthy.
3. Orchestrator kill và restart toàn bộ cả 3 container.
4. Trong lúc khởi động lại, cả cụm không còn instance nào để xử lý request (sập hoàn toàn).
5. Redis phục hồi nhưng service vẫn downtime thêm một lúc do các container chưa khởi động xong.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

* Với Redis: `history_length` tăng đều đặn qua các container: 0, 2, 4, 6, 8, 10.
* Nếu dùng dict Python: Bộ nhớ nằm riêng ở mỗi container; request rải ngẫu nhiên sẽ khiến `history_length` nhảy lộn xộn (ví dụ: 0, 0, 0, 2, 2, 2...) vì container không chia sẻ được ngữ cảnh với nhau.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

* **Lỗi:** `ResolutionImpossible` khi build image 1-stage.
* **Nguyên nhân:** Dùng cờ `--progress=plain` soi log thấy do PyPI `Read timed out` vì mạng chậm, không phải xung đột gói.
* **Cách sửa:** Thêm biến môi trường `ENV PIP_DEFAULT_TIMEOUT=100` vào Dockerfile trước bước `pip install`.
