#!/bin/bash
# 录屏API测试脚本
# 默认服务器地址和端口
HOST="${HOST:-localhost}"
PORT="${PORT:-18080}"
BASE_URL="http://${HOST}:${PORT}"

echo "=========================================="
echo "录屏API测试脚本"
echo "服务器地址: ${BASE_URL}"
echo "=========================================="
echo ""

# 颜色输出
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 1. 检查API状态
echo -e "${YELLOW}[1] 检查录屏状态${NC}"
echo "请求: GET ${BASE_URL}/record/status"
echo ""
curl -s -X GET "${BASE_URL}/record/status" | jq '.' || curl -s -X GET "${BASE_URL}/record/status"
echo ""
echo "----------------------------------------"
echo ""

# 2. 开始录屏（使用默认参数）
echo -e "${YELLOW}[2] 开始录屏（使用默认参数）${NC}"
echo "请求: POST ${BASE_URL}/record/start"
echo "请求体: {}"
echo ""
RESPONSE=$(curl -s -X POST "${BASE_URL}/record/start" \
  -H "Content-Type: application/json" \
  -d '{}')
echo "$RESPONSE" | jq '.' || echo "$RESPONSE"
# 提取UUID
RECORDING_UUID=$(echo "$RESPONSE" | jq -r '.uuid' 2>/dev/null || echo "")
if [ -n "$RECORDING_UUID" ] && [ "$RECORDING_UUID" != "null" ]; then
  echo -e "${GREEN}录屏UUID: ${RECORDING_UUID}${NC}"
fi
echo ""
echo "----------------------------------------"
echo ""

# 3. 开始录屏（自定义参数）
echo -e "${YELLOW}[3] 开始录屏（自定义参数）${NC}"
echo "请求: POST ${BASE_URL}/record/start"
echo "请求体: {\"video_size\": \"1920x1080\", \"framerate\": 30, \"filename\": \"test-recording.mp4\"}"
echo ""
RESPONSE=$(curl -s -X POST "${BASE_URL}/record/start" \
  -H "Content-Type: application/json" \
  -d '{
    "video_size": "1920x1080",
    "framerate": 30,
    "filename": "test-recording.mp4"
  }')
echo "$RESPONSE" | jq '.' || echo "$RESPONSE"
echo ""
echo "----------------------------------------"
echo ""

# 4. 再次检查状态（应该显示正在录屏）
echo -e "${YELLOW}[4] 检查录屏状态（应该显示正在录屏）${NC}"
echo "请求: GET ${BASE_URL}/record/status"
echo ""
curl -s -X GET "${BASE_URL}/record/status" | jq '.' || curl -s -X GET "${BASE_URL}/record/status"
echo ""
echo "----------------------------------------"
echo ""

# 5. 等待几秒（模拟录屏过程）
echo -e "${YELLOW}[5] 等待5秒（模拟录屏过程）${NC}"
sleep 5
echo "等待完成"
echo ""
echo "----------------------------------------"
echo ""

# 6. 停止录屏（使用UUID）
echo -e "${YELLOW}[6] 停止录屏（使用UUID）${NC}"
if [ -n "$RECORDING_UUID" ] && [ "$RECORDING_UUID" != "null" ]; then
  echo "请求: POST ${BASE_URL}/record/stop"
  echo "请求体: {\"uuid\": \"${RECORDING_UUID}\"}"
  echo ""
  RESPONSE=$(curl -s -X POST "${BASE_URL}/record/stop" \
    -H "Content-Type: application/json" \
    -d "{\"uuid\": \"${RECORDING_UUID}\"}")
else
  echo "请求: POST ${BASE_URL}/record/stop"
  echo "请求体: {} (使用当前录制的UUID)"
  echo ""
  RESPONSE=$(curl -s -X POST "${BASE_URL}/record/stop" \
    -H "Content-Type: application/json" \
    -d '{}')
fi
echo "$RESPONSE" | jq '.' || echo "$RESPONSE"
echo ""
echo "----------------------------------------"
echo ""

# 7. 再次检查状态（应该显示已停止）
echo -e "${YELLOW}[7] 检查录屏状态（应该显示已停止）${NC}"
echo "请求: GET ${BASE_URL}/record/status"
echo ""
curl -s -X GET "${BASE_URL}/record/status" | jq '.' || curl -s -X GET "${BASE_URL}/record/status"
echo ""
echo "----------------------------------------"
echo ""

# 8. 通过UUID下载录屏文件
echo -e "${YELLOW}[8] 通过UUID下载录屏文件${NC}"
if [ -n "$RECORDING_UUID" ] && [ "$RECORDING_UUID" != "null" ]; then
  echo "请求: GET ${BASE_URL}/record/file?uuid=${RECORDING_UUID}"
  echo ""
  FILE_PATH=$(echo "$RESPONSE" | jq -r '.file' 2>/dev/null || echo "")
  if [ -n "$FILE_PATH" ] && [ "$FILE_PATH" != "null" ]; then
    FILENAME=$(basename "$FILE_PATH")
    echo "正在通过UUID下载文件到: ${FILENAME}"
    curl -s -X GET "${BASE_URL}/record/file?uuid=${RECORDING_UUID}" -o "${FILENAME}"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}下载成功: ${FILENAME}${NC}"
      ls -lh "${FILENAME}"
    else
      echo -e "${RED}下载失败${NC}"
    fi
  else
    echo "无法获取文件路径，尝试直接通过UUID下载..."
    curl -s -X GET "${BASE_URL}/record/file?uuid=${RECORDING_UUID}" -o "recording-${RECORDING_UUID}.mp4"
    if [ $? -eq 0 ]; then
      echo -e "${GREEN}下载成功: recording-${RECORDING_UUID}.mp4${NC}"
      ls -lh "recording-${RECORDING_UUID}.mp4"
    else
      echo -e "${RED}下载失败${NC}"
    fi
  fi
else
  echo "没有UUID，尝试下载最后一个文件..."
  curl -s -X GET "${BASE_URL}/record/file" -o "recording.mp4"
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}下载成功: recording.mp4${NC}"
    ls -lh "recording.mp4"
  else
    echo -e "${RED}下载失败${NC}"
  fi
fi
echo ""
echo "----------------------------------------"
echo ""

# 9. 下载指定文件名的录屏文件
echo -e "${YELLOW}[9] 下载指定文件名的录屏文件${NC}"
echo "请求: GET ${BASE_URL}/record/file?name=test-recording.mp4"
echo ""
curl -s -X GET "${BASE_URL}/record/file?name=test-recording.mp4" -o "test-recording-download.mp4"
if [ $? -eq 0 ]; then
  echo -e "${GREEN}下载成功: test-recording-download.mp4${NC}"
  ls -lh "test-recording-download.mp4"
else
  echo -e "${RED}下载失败（文件可能不存在）${NC}"
fi
echo ""
echo "=========================================="
echo "测试完成"
echo "=========================================="
