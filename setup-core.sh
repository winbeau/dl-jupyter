#!/usr/bin/env bash
set -e

echo "[0] 开始执行环境恢复脚本 (dl-setup)"

# ================================
# 工具函数
# ================================
install_conda_package() {
    local package="$1"
    local description="$2"
    echo "  → 安装 ${description}: ${package}"
    if conda install -n pyl "${package}" -y -q; then
        echo "    ✓ ${description} 安装成功"
    else
        echo "    ✗ ${description} 安装失败，跳过"
    fi
}

install_pip_package() {
    local package="$1"
    local description="$2"
    echo "  → 安装 ${description}: ${package}"
    if pip install "${package}" --quiet; then
        echo "    ✓ ${description} 安装成功"
    else
        echo "    ✗ ${description} 安装失败，跳过"
    fi
}

# ================================
# Step 1: 更新系统软件
# ================================
echo "[1] 更新系统软件..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget git bzip2

# ================================
# Step 2: 安装 Miniconda (如未安装)
# ================================
if [ ! -d "$HOME/miniconda" ]; then
    echo "[2] 未检测到 Miniconda，开始安装..."
    wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
    bash ~/miniconda.sh -b -p $HOME/miniconda
    rm ~/miniconda.sh
else
    echo "[2] 已检测到 Miniconda，跳过安装"
fi

# 初始化 conda
eval "$($HOME/miniconda/bin/conda shell.bash hook)"
conda init bash || true

# ================================
# Step 3: 接受 Anaconda ToS
# ================================
echo "[3] 接受 Anaconda ToS..."
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/main || true
conda tos accept --override-channels --channel https://repo.anaconda.com/pkgs/r || true

echo "[4] 配置 conda 镜像源 (清华)"
conda config --remove-key channels || true
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/main/
conda config --add channels https://mirrors.tuna.tsinghua.edu.cn/anaconda/pkgs/r/
conda config --add channels conda-forge
conda config --set show_channel_urls yes

# ================================
# Step 5: 更新 conda & pip
# ================================
echo "[5] 更新 conda & pip..."
conda update -n base -c defaults conda -y || true
pip install --upgrade pip || true

# ================================
# Step 6: 创建核心环境
# ================================
echo "[6] 创建核心环境..."
if [ -f conda-envs/pyl.core.yml ]; then
    conda env create -f conda-envs/pyl.core.yml || {
        echo "[6-error] 核心环境创建失败，手动创建最小环境"
        conda create -n pyl python=3.10 pip jupyter jupyterlab ipykernel -y
    }
else
    echo "[6-error] 未找到 conda-envs/pyl.core.yml 文件！"
    echo "创建最小环境..."
    conda create -n pyl python=3.10 pip jupyter jupyterlab ipykernel -y
fi

# ================================
# Step 7: 激活环境
# ================================
echo "[7] 激活 pyl 环境..."
eval "$($HOME/miniconda/bin/conda shell.bash hook)"
conda activate pyl

# ================================
# Step 8: 检测 GPU 并安装 PyTorch
# ================================
echo "[8] 安装 PyTorch..."
if command -v nvidia-smi &> /dev/null; then
    echo "[8] 检测到 NVIDIA GPU → 安装 CUDA 版 PyTorch"
    install_conda_package "pytorch pytorch-cuda=11.8 torchvision torchaudio -c pytorch -c nvidia" "PyTorch (CUDA)"
else
    echo "[8] 未检测到 NVIDIA GPU → 安装 CPU 版 PyTorch"
    install_conda_package "pytorch torchvision torchaudio cpuonly -c pytorch" "PyTorch (CPU)"
fi

# ================================
# Step 9: 安装 d2l (Dive into Deep Learning)
# ================================
echo "[9] 安装 d2l (Dive into Deep Learning)..."
install_pip_package "d2l" "D2L (Dive into Deep Learning)"

# ================================
# Step 10: 逐步安装科学计算包
# ================================
echo "[10] 安装科学计算包..."

# 数据处理
install_conda_package "numpy" "NumPy"
install_conda_package "pandas" "Pandas"
install_conda_package "scipy" "SciPy"

# 可视化
install_conda_package "matplotlib" "Matplotlib"
install_conda_package "seaborn" "Seaborn"

# 机器学习
install_conda_package "scikit-learn" "Scikit-learn"

# Jupyter 组件
install_conda_package "notebook" "Jupyter Notebook"
install_conda_package "ipywidgets" "IPython Widgets"

# 工具包
install_conda_package "tqdm" "TQDM"
install_conda_package "pillow" "Pillow"

# OpenCV (容易失败，用 pip 安装)
echo "  → 安装 OpenCV (通过pip)"
if pip install opencv-python --quiet; then
    echo "    ✓ OpenCV 安装成功"
else
    echo "    ✗ OpenCV 安装失败，跳过"
fi

# Node.js 相关
install_conda_package "nodejs" "Node.js"
install_conda_package "yarn" "Yarn"

# ================================
# Step 11: 注册 Jupyter 内核
# ================================
echo "[11] 注册 Jupyter 内核..."
python -m ipykernel install --user --name=pyl --display-name "Python (pyl)" || true

# ================================
# Step 12: 环境验证
# ================================
echo "[12] 验证环境..."
python -c "
import sys
print(f'Python 版本: {sys.version}')
try:
    import torch
    print(f'PyTorch 版本: {torch.__version__}')
    print(f'CUDA 可用: {torch.cuda.is_available()}')
except ImportError:
    print('PyTorch 未安装')

try:
    import numpy as np
    print(f'NumPy 版本: {np.__version__}')
except ImportError:
    print('NumPy 未安装')

try:
    import pandas as pd
    print(f'Pandas 版本: {pd.__version__}')
except ImportError:
    print('Pandas 未安装')

try:
    import d2l
    print(f'D2L 版本: {d2l.__version__}')
except ImportError:
    print('D2L 未安装')
" || true

# ================================
# 完成
# ================================
echo ""
echo "[✔] 环境恢复完成！"

# 显示安装失败包汇总
if [ ${#FAILED_PACKAGES[@]} -eq 0 ]; then
    echo "🎉 所有包都安装成功！"
else
    echo ""
    echo "⚠️  安装失败的包汇总 (${#FAILED_PACKAGES[@]}个)："
    echo "----------------------------------------"
    for package in "${FAILED_PACKAGES[@]}"; do
        echo "  ❌ $package"
    done
    echo "----------------------------------------"
    echo ""
    echo "💡 你可以稍后手动安装这些包："
    echo "   conda activate pyl"
    for package in "${FAILED_PACKAGES[@]}"; do
        if [[ "$package" == *"conda:"* ]]; then
            pkg_name=$(echo "$package" | sed 's/.*conda: \([^)]*\).*/\1/')
            echo "   conda install $pkg_name"
        elif [[ "$package" == *"pip:"* ]]; then
            pkg_name=$(echo "$package" | sed 's/.*pip: \([^)]*\).*/\1/')
            echo "   pip install $pkg_name"
        fi
    done
fi

echo ""
echo "已安装的包汇总："
conda list | head -20
echo "..."
echo ""
echo "现在可以运行："
echo "    conda activate pyl      # 激活环境"
echo "    jupyter lab            # 启动 Jupyter Lab"
echo ""
echo "高级包安装："
echo "    bash optional-packages.sh"
