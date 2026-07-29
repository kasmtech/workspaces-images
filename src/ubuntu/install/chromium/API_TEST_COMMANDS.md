# 录屏API测试命令

默认服务器地址: `http://localhost:18080`

如果服务器运行在其他地址，请替换 `localhost:18080` 为实际地址。

**重要：** 每个录屏会话都有一个唯一的UUID标识符。开始录屏时会返回UUID，停止录屏和获取文件时需要使用这个UUID。

---

## 1. 检查录屏状态

```bash
curl -X GET http://localhost:18080/record/status
```

**格式化输出（需要 jq）:**
```bash
curl -s -X GET http://localhost:18080/record/status | jq '.'
```

**预期响应:**
```json
{
  "recording": false,
  "current_uuid": null,
  "current_file": null,
  "last_file": null,
  "display": ":1",
  "recording_dir": "/home/kasm-user/recordings"
}
```

**响应字段说明:**
- `recording`: 是否正在录屏
- `current_uuid`: 当前录屏会话的UUID（如果正在录屏）
- `current_file`: 当前录制的文件路径
- `last_file`: 最后一个完成的录屏文件路径

---

## 2. 开始录屏（使用默认参数）

```bash
curl -X POST http://localhost:18080/record/start \
  -H "Content-Type: application/json" \
  -d '{}'
```

**格式化输出:**
```bash
curl -s -X POST http://localhost:18080/record/start \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
```

**预期响应:**
```json
{
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "file": "/home/kasm-user/recordings/recording-550e8400-20240101T120000Z.mp4",
  "video_size": "1920x1080",
  "framerate": 25,
  "display": ":1",
  "recording_dir": "/home/kasm-user/recordings"
}
```

**注意：** 响应中包含 `uuid` 字段，这是本次录屏的唯一标识符。后续停止录屏和获取文件时需要使用这个UUID。

---

## 3. 开始录屏（自定义参数）

```bash
curl -X POST http://localhost:18080/record/start \
  -H "Content-Type: application/json" \
  -d '{
    "video_size": "1920x1080",
    "framerate": 30,
    "filename": "my-recording.mp4"
  }'
```

**格式化输出:**
```bash
curl -s -X POST http://localhost:18080/record/start \
  -H "Content-Type: application/json" \
  -d '{
    "video_size": "1920x1080",
    "framerate": 30,
    "filename": "my-recording.mp4"
  }' | jq '.'
```

**参数说明:**
- `video_size`: 视频分辨率，格式为 "WIDTHxHEIGHT"（可选）
- `framerate`: 帧率，整数（可选）
- `filename`: 自定义文件名（可选）

---

## 4. 停止录屏

**使用UUID停止录屏（推荐）:**
```bash
curl -X POST http://localhost:18080/record/stop \
  -H "Content-Type: application/json" \
  -d '{"uuid": "550e8400-e29b-41d4-a716-446655440000"}'
```

**不使用UUID（停止当前录制的会话）:**
```bash
curl -X POST http://localhost:18080/record/stop \
  -H "Content-Type: application/json" \
  -d '{}'
```

**格式化输出:**
```bash
curl -s -X POST http://localhost:18080/record/stop \
  -H "Content-Type: application/json" \
  -d '{"uuid": "550e8400-e29b-41d4-a716-446655440000"}' | jq '.'
```

**预期响应:**
```json
{
  "uuid": "550e8400-e29b-41d4-a716-446655440000",
  "file": "/home/kasm-user/recordings/recording-550e8400-20240101T120000Z.mp4",
  "size": 1234567,
  "exists": true
}
```

**响应字段说明:**
- `uuid`: 录屏会话的UUID
- `file`: 录屏文件的完整路径
- `size`: 文件大小（字节）
- `exists`: 文件是否存在

---

## 5. 通过UUID下载录屏文件（推荐）

```bash
curl -X GET "http://localhost:18080/record/file?uuid=550e8400-e29b-41d4-a716-446655440000" -o recording.mp4
```

**带进度条:**
```bash
curl -X GET "http://localhost:18080/record/file?uuid=550e8400-e29b-41d4-a716-446655440000" -o recording.mp4 --progress-bar
```

---

## 6. 下载录屏文件（最后一个录制的文件，不使用UUID）

```bash
curl -X GET http://localhost:18080/record/file -o recording.mp4
```

---

## 7. 下载指定文件名的录屏文件

```bash
curl -X GET "http://localhost:18080/record/file?name=my-recording.mp4" -o my-recording.mp4
```

**或者使用绝对路径:**
```bash
curl -X GET "http://localhost:18080/record/file?name=/home/kasm-user/recordings/my-recording.mp4" -o my-recording.mp4
```

**注意：** 参数优先级：`uuid` > `name` > 最后一个录制的文件

---

## 完整测试流程示例（使用UUID）

```bash
# 1. 检查状态
curl -s -X GET http://localhost:18080/record/status | jq '.'

# 2. 开始录屏并获取UUID
START_RESPONSE=$(curl -s -X POST http://localhost:18080/record/start \
  -H "Content-Type: application/json" \
  -d '{"video_size": "1920x1080", "framerate": 30}')
echo "$START_RESPONSE" | jq '.'

# 3. 提取UUID
RECORDING_UUID=$(echo "$START_RESPONSE" | jq -r '.uuid')
echo "录屏UUID: $RECORDING_UUID"

# 4. 等待几秒（录屏中）
sleep 5

# 5. 检查状态（应该显示正在录屏）
curl -s -X GET http://localhost:18080/record/status | jq '.'

# 6. 使用UUID停止录屏
STOP_RESPONSE=$(curl -s -X POST http://localhost:18080/record/stop \
  -H "Content-Type: application/json" \
  -d "{\"uuid\": \"$RECORDING_UUID\"}")
echo "$STOP_RESPONSE" | jq '.'

# 7. 通过UUID下载文件
curl -X GET "http://localhost:18080/record/file?uuid=$RECORDING_UUID" -o "recording-${RECORDING_UUID}.mp4"

# 8. 验证文件
ls -lh "recording-${RECORDING_UUID}.mp4"
```

---

## 错误处理示例

### 尝试在录屏已运行时再次开始录屏
```bash
curl -s -X POST http://localhost:18080/record/start \
  -H "Content-Type: application/json" \
  -d '{}' | jq '.'
# 预期: {"error": "Recording already in progress"}
```

### 尝试在没有录屏时停止录屏
```bash
curl -s -X POST http://localhost:18080/record/stop \
  -H "Content-Type: application/json" | jq '.'
# 预期: {"error": "No active recording"}
```

### 尝试下载不存在的文件
```bash
curl -s -X GET "http://localhost:18080/record/file?name=non-existent.mp4"
# 预期: {"error": "Recording not found"}
```

---

## 使用 Python requests 库测试

```python
import requests
import time

BASE_URL = "http://localhost:18080"

# 1. 检查状态
response = requests.get(f"{BASE_URL}/record/status")
print("状态:", response.json())

# 2. 开始录屏并获取UUID
response = requests.post(
    f"{BASE_URL}/record/start",
    json={"video_size": "1920x1080", "framerate": 30}
)
start_result = response.json()
print("开始录屏:", start_result)

# 3. 提取UUID
recording_uuid = start_result.get("uuid")
print(f"录屏UUID: {recording_uuid}")

# 4. 等待5秒
time.sleep(5)

# 5. 使用UUID停止录屏
response = requests.post(
    f"{BASE_URL}/record/stop",
    json={"uuid": recording_uuid}
)
stop_result = response.json()
print("停止录屏:", stop_result)

# 6. 通过UUID下载文件
if stop_result.get("exists"):
    file_response = requests.get(f"{BASE_URL}/record/file?uuid={recording_uuid}")
    filename = f"recording-{recording_uuid}.mp4"
    with open(filename, "wb") as f:
        f.write(file_response.content)
    print(f"文件已下载: {filename}")
```

---

## 使用 HTTPie 测试（更简洁）

```bash
# 安装: pip install httpie

# 检查状态
http GET localhost:18080/record/status

# 开始录屏
http POST localhost:18080/record/start video_size=1920x1080 framerate=30

# 停止录屏
http POST localhost:18080/record/stop

# 下载文件
http GET localhost:18080/record/file --download
```
