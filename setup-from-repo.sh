#!/usr/bin/env bash
# setup_from_repo.sh
# 目的：从仓库自动恢复 pyl conda 环境、Jupyter 配置与 kernel
# 用法：在仓库根运行： bash setup_from_repo.sh
# 注意：脚本会尝试使用 sudo 安装系统包（如 apt update）。请确保有 sudo 权限。

set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_NAME="pyl"
LOG="$REPO_DIR/setup.log"
exec > >(tee -a "$LOG") 2>&1

echo
echo "=== setup_from_repo.sh START ==="
date
echo "Repository: $REPO_DIR"
echo "Log: $LOG"
echo

# ---------- helper ----------
die() { echo "ERROR: $*" >&2; echo "See $LOG for details."; exit 1; }
info() { echo -e "\n[INFO] $*\n"; }

# ---------- Step 0: 更新系统并安装基础工具 ----------
info "Step 0 — 更新系统并安装基础工具 (sudo required)"
sudo apt update || die "apt update failed"
sudo apt upgrade -y || die "apt upgrade failed"
sudo apt install -y wget curl git build-essential ca-certificates gnupg lsb-release || die "apt install failed"

# ---------- Step 1: 安装/初始化 Miniconda ----------
if ! command -v conda >/dev/null 2>&1; then
  info "Step 1 — 未检测到 conda，开始安装 Miniconda（静默安装）"
  MINICONDA_INSTALLER="/tmp/miniconda_install.sh"
  wget -q https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O "$MINICONDA_INSTALLER" || die "下载 Miniconda 失败"
  bash "$MINICONDA_INSTALLER" -b -p "$HOME/miniconda" || die "Miniconda 安装失败"
  rm -f "$MINICONDA_INSTALLER"
  export PATH="$HOME/miniconda/bin:$PATH"
  # 让当前 shell 能使用 conda
  eval "$($HOME/miniconda/bin/conda shell.bash hook)"
  # 初始化 bash（会修改 ~/.bashrc）
  "$HOME/miniconda/bin/conda" init bash || true
  info "Miniconda 安装并初始化完成"
else
  info "Step 1 — 检测到 conda，初始化 shell hook"
  # 如果 conda 已存在，确保当前 shell 能识别 conda
  eval "$(conda shell.bash hook)"
fi

# ---------- Step 1.5: 接受 Anaconda ToS（避免交互阻塞） ----------
info "Step 1.5 — 接受 Anaconda 通用 Terms of Service（避免交互阻塞）"
# 这些命令在某些 conda 版本中可用，失败不致命
if command -v conda >/dev/null 2>&1; then
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
  conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true
fi

# ---------- Step 2: 更新 conda 并安装 mamba（加速求解） ----------
echo "[2.1] 配置 conda 镜像源 (清华)"
conda config --remove-key channels || true
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r/
conda config --add channels conda-forge
conda config --set show_channel_urls yes

info "Step 2 — 升级 conda，并尝试安装 mamba（提高依赖求解成功率）"
conda update -n base -c defaults -y conda || echo "[WARN] conda update failed, continuing"
# try install mamba (preferred), else fallback install conda-forge micromamba if needed
if ! command -v mamba >/dev/null 2>&1; then
  echo "[INFO] 安装 mamba 到 base 环境 (可能需要一些时间)..."
  conda install -n base -c conda-forge -y mamba || echo "[WARN] 安装 mamba 失败，继续使用 conda"
fi

# ---------- Helper to try creating env with various strategies ----------
try_create_env() {
  local file="$1"
  local tool="$2"  # "mamba" or "conda"
  local extra_args="${3:-}"
  if [ ! -f "$file" ]; then
    echo "[SKIP] $file not found"
    return 1
  fi
  echo "[TRY] $tool env create -f $file $extra_args"
  if command -v "$tool" >/dev/null 2>&1; then
    if "$tool" env create -f "$file" -y $extra_args; then
      echo "[OK] Created env from $file using $tool"
      return 0
    else
      echo "[FAIL] $tool env create -f $file failed"
      return 1
    fi
  else
    echo "[NO] $tool not installed"
    return 1
  fi
}

# ---------- Step 3: 优先使用 conda-pack（如果仓库包含 tarball） ----------
if [ -f "$REPO_DIR/${ENV_NAME}-conda-pack.tar.gz" ]; then
  info "Step 3 — 检测到 conda-pack tarball，优先解包以尽可能原封不动还原环境"
  TDIR="$HOME/conda_packed_${ENV_NAME}"
  mkdir -p "$TDIR"
  tar -xzf "$REPO_DIR/${ENV_NAME}-conda-pack.tar.gz" -C "$TDIR" || echo "[WARN] conda-pack 解包失败，继续尝试 yml 恢复"
  if [ -f "$TDIR/bin/conda-unpack" ]; then
    echo "[INFO] 运行 conda-unpack 修正路径..."
    "$TDIR/bin/conda-unpack" || echo "[WARN] conda-unpack 运行失败"
  fi
  info "解包完成：$TDIR （请检查并根据需要使用该环境）"
fi

# ---------- Step 4: 尝试按次序用 yml 创建环境（from-history -> no-builds -> full -> explicit） ----------
info "Step 4 — 尝试按优先级用仓库中的 yml 恢复环境"
CREATED=false
YMLS=(
  "$REPO_DIR/conda-envs/${ENV_NAME}.from-history.yml"
  "$REPO_DIR/conda-envs/${ENV_NAME}.no-builds.yml"
  "$REPO_DIR/conda-envs/${ENV_NAME}.full.yml"
)
# Try with mamba first (if available), fallback to conda (classic solver and default solver)
for y in "${YMLS[@]}"; do
  if [ -f "$y" ]; then
    # 1) try mamba (fast)
    if command -v mamba >/dev/null 2>&1; then
      if try_create_env "$y" mamba; then CREATED=true; break; fi
    fi
    # 2) try conda with classic solver (sometimes更能解决冲突)
    if try_create_env "$y" conda "--experimental-solver=classic"; then CREATED=true; break; fi
    # 3) try conda default
    if try_create_env "$y" conda; then CREATED=true; break; fi
  fi
done

# 4) try explicit file if exists (conda create --file)
if ! $CREATED && [ -f "$REPO_DIR/conda-envs/${ENV_NAME}.conda-explicit.txt" ]; then
  info "尝试使用 explicit list 创建（conda create --file）"
  if conda create -n "${ENV_NAME}" --file "$REPO_DIR/conda-envs/${ENV_NAME}.conda-explicit.txt" -y; then
    CREATED=true
  else
    echo "[WARN] explicit install 失败"
  fi
fi

# ---------- Step 5: 若上面所有方法都失败，则回退到最小 env + pip 安装 ----------
if ! $CREATED; then
  info "Step 5 — 所有自动创建策略失败，开始回退：创建最小 Python 环境并用 pip 安装（保底）"
  # 尝试从 yml 中提取 python 版本（否则默认 3.10）
  PYVER="3.10"
  for y in "${YMLS[@]}"; do
    if [ -f "$y" ]; then
      # grep python spec like "python=3.10" or "python 3.10"
      pv=$(grep -Eo "python[ <=]*[0-9]+\.[0-9]+" "$y" | head -n1 || true)
      if [ -n "$pv" ]; then
        # extract digits
        PYVER=$(echo "$pv" | grep -Eo "[0-9]+\.[0-9]+")
        break
      fi
    fi
  done
  echo "[INFO] 使用 Python $PYVER 创建最小环境：conda create -n ${ENV_NAME} python=${PYVER} -y"
  conda create -n "${ENV_NAME}" python="${PYVER}" -y || die "创建最小环境失败，请手动检查 $LOG"
  echo "[INFO] 激活并用 pip 安装 pip-freeze 列表（如果存在）"
  conda activate "${ENV_NAME}"
  if [ -f "$REPO_DIR/conda-envs/${ENV_NAME}.pip-freeze.txt" ]; then
    pip install --upgrade pip setuptools wheel || true
    pip install -r "$REPO_DIR/conda-envs/${ENV_NAME}.pip-freeze.txt" || echo "[WARN] pip 安装部分包失败（参见 $LOG），请手动修正"
  else
    echo "[WARN] pip-freeze.txt 不存在，跳过 pip 安装"
  fi
  conda deactivate
else
  info "环境已成功创建（名称可能为 ${ENV_NAME}）"
fi

# ---------- Step 6: 注册 Jupyter kernel ----------
info "Step 6 — 注册 Jupyter kernel（name: ${ENV_NAME}）"
if conda env list | awk '{print $1}' | grep -q "^${ENV_NAME}$"; then
  conda activate "${ENV_NAME}"
  python -m ipykernel install --user --name "${ENV_NAME}" --display-name "Python (${ENV_NAME})" || echo "[WARN] ipykernel install 失败"
  conda deactivate
else
  echo "[WARN] 未检测到 ${ENV_NAME} 环境，跳过 kernel 注册"
fi

# ---------- Step 7: 恢复 Jupyter 配置 ----------
info "Step 7 — 恢复 Jupyter 配置（如果 jupyter-config/tgz 存在）"
if [ -f "$REPO_DIR/jupyter/jupyter-config.tgz" ]; then
  echo "[INFO] 备份现有 ~/.jupyter 并解压仓库的配置"
  [ -d "$HOME/.jupyter" ] && mv "$HOME/.jupyter" "$HOME/.jupyter.bak_$(date +%s)" || true
  tar xzf "$REPO_DIR/jupyter/jupyter-config.tgz" -C "$HOME" || echo "[WARN] 解压 jupyter-config.tgz 失败"
fi
if [ -f "$REPO_DIR/jupyter/jupyterlab-config.tgz" ]; then
  echo "[INFO] 恢复 JupyterLab 本地设置（~/.local/share/jupyter）"
  [ -d "$HOME/.local/share/jupyter" ] && mv "$HOME/.local/share/jupyter" "$HOME/.local/share/jupyter.bak_$(date +%s)" || true
  tar xzf "$REPO_DIR/jupyter/jupyterlab-config.tgz" -C "$HOME" || echo "[WARN] 解压 jupyterlab-config.tgz 失败"
fi

# ---------- Step 8: 尝试安装/构建 JupyterLab（在环境中） ----------
info "Step 8 — 在 pyl 环境中安装并尝试构建 JupyterLab（提高兼容性）"
if conda env list | awk '{print $1}' | grep -q "^${ENV_NAME}$"; then
  conda activate "${ENV_NAME}"
  # 安装 jupyterlab（优先 conda-forge）
  conda install -y -c conda-forge jupyterlab || pip install jupyterlab || echo "[WARN] jupyterlab 安装失败"
  # 尝试 build（若安装了需要构建的 labextensions）
  jupyter lab build || echo "[WARN] jupyter lab build 失败或跳过"
  conda deactivate
else
  echo "[WARN] 环境 ${ENV_NAME} 不存在，跳过 JupyterLab 安装/构建"
fi

# ---------- Step 9: 最后检查与提示 ----------
info "Step 9 — 检查与提示"
echo "conda envs:"
conda info --envs || true
echo
echo "jupyter kernels:"
jupyter kernelspec list || true

echo
echo "Setup complete. If you encounter dependency conflicts (e.g. ffmpeg/fontconfig/libtheora/libuuid), see the instructions below in this log or open an issue."
echo "Log file: $LOG"
echo "=== setup_from_repo.sh END ==="
date

