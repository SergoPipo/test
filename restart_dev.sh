#!/usr/bin/env bash
# Перезапуск backend (FastAPI/uvicorn) + frontend (Vite) для локальной разработки.
# Использование: ./restart_dev.sh   или   bash restart_dev.sh

set -u

ROOT="/Users/sergopipo/Documents/Claude_Code/Test"
BACKEND="$ROOT/Develop/backend"
FRONTEND="$ROOT/Develop/frontend"
LOG_DIR="/tmp/moex-dev-logs"
BACK_PORT=8000
FRONT_PORT=5173

mkdir -p "$LOG_DIR"

kill_port() {
  local port="$1"
  local pids
  pids=$(lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null || true)
  if [ -n "$pids" ]; then
    echo "  останавливаю PID(s) $pids на порту $port"
    kill $pids 2>/dev/null || true
    sleep 1
    pids=$(lsof -ti tcp:"$port" -sTCP:LISTEN 2>/dev/null || true)
    if [ -n "$pids" ]; then
      echo "  принудительно (-9): $pids"
      kill -9 $pids 2>/dev/null || true
    fi
  fi
}

echo "==> 1/4 Останавливаю старые процессы"
kill_port "$BACK_PORT"
kill_port "$FRONT_PORT"

echo "==> 2/4 Применяю миграции backend"
cd "$BACKEND"
# shellcheck disable=SC1091
source .venv/bin/activate
alembic upgrade head || { echo "ERROR: alembic upgrade head упал"; exit 1; }

echo "==> 3/4 Запускаю backend (uvicorn) на http://127.0.0.1:$BACK_PORT"
nohup uvicorn app.main:app --reload --host 127.0.0.1 --port "$BACK_PORT" \
  > "$LOG_DIR/backend.log" 2>&1 &
BACK_PID=$!
echo "    PID=$BACK_PID  log=$LOG_DIR/backend.log"

echo "==> 4/4 Запускаю frontend (vite) на http://localhost:$FRONT_PORT"
cd "$FRONTEND"
nohup pnpm dev > "$LOG_DIR/frontend.log" 2>&1 &
FRONT_PID=$!
echo "    PID=$FRONT_PID  log=$LOG_DIR/frontend.log"

echo "==> Жду готовности backend (до 25 сек)"
for i in $(seq 1 25); do
  code=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$BACK_PORT/api/v1/health" 2>/dev/null || echo "000")
  if [ "$code" = "200" ]; then
    echo "    backend готов (HTTP 200)"
    break
  fi
  if [ "$i" = "25" ]; then
    echo "    WARNING: backend не ответил 200 за 25 сек — проверь $LOG_DIR/backend.log"
  fi
  sleep 1
done

echo ""
echo "Готово."
echo "  Backend:  http://127.0.0.1:$BACK_PORT  (PID $BACK_PID)"
echo "  Frontend: http://localhost:$FRONT_PORT (PID $FRONT_PID)"
echo "  Логи:     $LOG_DIR/{backend,frontend}.log"
echo ""
echo "Остановить вручную: lsof -ti tcp:$BACK_PORT -sTCP:LISTEN | xargs kill ; lsof -ti tcp:$FRONT_PORT -sTCP:LISTEN | xargs kill"
