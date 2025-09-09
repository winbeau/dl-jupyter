#!/usr/bin/env bash
set -e

echo "[0] 开始执行环境恢复脚本 (dl-setup)"

# ================================
# 全局变量：失败包记录
# ================================
FAILED_PACKAGES=()

# ================================
# 工具函数
# ================================
install_conda_package() {
    local package="$1"
    local description="$2"
    echo "  → 安装 ${description}: ${package}"
    if conda install -n pyl "${package}" -y -q; then
        echo "    ✓ ${description} 安装成功"
        return 0
    else
        echo "    ✗ ${description} 安装失败，跳过"
        FAILED_PACKAGES+=("conda: ${description} (${package})")
        return 1
    fi
}

install_pip_package() {
    local package="$1"
    local description="$2"
    echo "  → 安装 ${description}: ${package}"
    if pip install "${package}" --quiet; then
        echo "    ✓ ${description} 安装成功"
        return 0
    else
        echo "    ✗ ${description} 安装失败，跳过"
        FAILED_PACKAGES+=("pip: ${description} (${package})")
        return 1
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
# Step 5.1: 配置 pip 清华镜像
# ================================
echo "[5] 配置 pip 镜像源 (清华)..."
mkdir -p ~/.pip
cat > ~/.pip/pip.conf << EOF
[global]
index-url = https://pypi.tuna.tsinghua.edu.cn/simple/
trusted-host = pypi.tuna.tsinghua.edu.cn
timeout = 30
retries = 2
EOF
echo "    ✓ pip 清华镜像配置完成"

# ================================
# Step 6: 更新 conda & pip
# ================================
echo "[6] 更新 conda & pip..."
conda update -n base -c defaults conda -y || true
pip install --upgrade pip || true


# ================================
# Step 7: 创建核心环境
# ================================
echo "[7] 创建核心环境..."
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
# Step 8: 激活环境
# ================================
echo "[8] 激活 pyl 环境..."
eval "$($HOME/miniconda/bin/conda shell.bash hook)"
conda activate pyl

# ================================
# Step 9: 检测 GPU 并安装 PyTorch
# ================================
echo "[9] 安装 PyTorch..."

pytorch_installed=false

if command -v nvidia-smi &> /dev/null; then
    echo "[9] 检测到 NVIDIA GPU → 安装 CUDA 版 PyTorch"

    # 首先尝试 conda 安装
    echo "  → 尝试 conda 安装 PyTorch (CUDA)"
    if conda install -n pyl pytorch pytorch-cuda=11.8 torchvision torchaudio -c pytorch -c nvidia -y -q; then
        echo "    ✓ PyTorch (CUDA) conda 安装成功"
        pytorch_installed=true
    else
        echo "    ✗ PyTorch (CUDA) conda 安装失败，尝试 pip 安装"

        # conda 失败后尝试 pip 安装 - 先尝试清华源
        echo "  → 尝试 pip 安装 PyTorch (CUDA) [清华源]"
        if conda run -n pyl pip install torch torchvision torchaudio --index-url https://pypi.tuna.tsinghua.edu.cn/simple/ --trusted-host pypi.tuna.tsinghua.edu.cn --quiet; then
            echo "    ✓ PyTorch (CUDA) pip 安装成功（清华镜像）"
            pytorch_installed=true
        else
            echo "    ✗ PyTorch (CUDA) 清华源失败，尝试官方源"
            # 尝试官方源
            if conda run -n pyl pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 --quiet; then
                echo "    ✓ PyTorch (CUDA) pip 安装成功（官方源）"
                pytorch_installed=true
            else
                echo "    ✗ PyTorch (CUDA) 所有安装方式都失败"
                FAILED_PACKAGES+=("PyTorch (CUDA)")
            fi
        fi
    fi

else
    echo "[9] 未检测到 NVIDIA GPU → 安装 CPU 版 PyTorch"

    # 首先尝试 conda 安装
    echo "  → 尝试 conda 安装 PyTorch (CPU)"
    if conda install -n pyl pytorch torchvision torchaudio cpuonly -c pytorch -y -q; then
        echo "    ✓ PyTorch (CPU) conda 安装成功"
        pytorch_installed=true
    else
        echo "    ✗ PyTorch (CPU) conda 安装失败，尝试 pip 安装"

        # conda 失败后尝试 pip 安装 - 先尝试清华源
        echo "  → 尝试 pip 安装 PyTorch (CPU) [清华源]"
        if conda run -n pyl pip install torch torchvision torchaudio --index-url https://pypi.tuna.tsinghua.edu.cn/simple/ --trusted-host pypi.tuna.tsinghua.edu.cn --quiet; then
            echo "    ✓ PyTorch (CPU) pip 安装成功（清华镜像）"
            pytorch_installed=true
        else
            echo "    ✗ PyTorch (CPU) 清华源失败，尝试官方源"
            # 尝试官方源
            if conda run -n pyl pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu --quiet; then
                echo "    ✓ PyTorch (CPU) pip 安装成功（官方源）"
                pytorch_installed=true
            else
                echo "    ✗ PyTorch (CPU) 所有安装方式都失败"
                FAILED_PACKAGES+=("PyTorch (CPU)")
            fi
        fi
    fi
fi

# ================================
# Step 10: 安装 d2l (Dive into Deep Learning)
# ================================
echo "[10] 安装 d2l (Dive into Deep Learning)..."
install_pip_package "d2l" "D2L (Dive into Deep Learning)"

# ================================
# Step 11: 逐步安装科学计算包
# ================================
echo "[11] 安装科学计算包..."

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

# OpenCV (容易失败，用 pip 安装，带超时检查)
echo "  → 安装 OpenCV (通过pip，60s超时检查)"
opencv_installed=false

# 设置超时时间为60秒
timeout 60s bash -c '
    if conda run -n pyl pip install opencv-python --quiet; then
        echo "    ✓ OpenCV 安装成功"
        exit 0
    else
        echo "    ✗ OpenCV 安装失败"
        exit 1
    fi
' && opencv_installed=true

if [ "$opencv_installed" = false ]; then
    echo "    ⚠️ OpenCV 安装超时或失败，跳过"
    FAILED_PACKAGES+=("pip: OpenCV (opencv-python)")
fi

# Node.js 相关
install_conda_package "nodejs" "Node.js"
install_conda_package "yarn" "Yarn"

# ================================
# Step 11: 注册 Jupyter 内核
# ================================
echo "[11] 注册 Jupyter 内核..."
conda run -n pyl python -m ipykernel install --user --name=pyl --display-name "Python (pyl)" || true

# ================================
# Step 12: 环境验证
# ================================
echo "[12] 验证环境..."
conda run -n pyl python -c "
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

try:
    import cv2
    print(f'OpenCV 版本: {cv2.__version__}')
except ImportError:
    print('OpenCV 未安装')
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
            pkg_name=$(echo "$package" | sed 's/.*(\([^)]*\)).*/\1/')
            echo "   conda install $pkg_name"
        elif [[ "$package" == *"pip:"* ]]; then
            pkg_name=$(echo "$package" | sed 's/.*(\([^)]*\)).*/\1/')
            echo "   pip install $pkg_name"
        else
            echo "   # 手动安装: $package"
        fi
    done
    echo ""
    echo "特别提示：如果 OpenCV 安装失败，可以尝试："
    echo "   conda activate pyl"
    echo "   pip install opencv-python -i https://pypi.tuna.tsinghua.edu.cn/simple/"
    echo "   # 或者使用 conda: conda install opencv -c conda-forge"
fi

echo ""
echo "已安装的包汇总："
conda run -n pyl conda list | head -20
echo "..."
echo ""
echo "初始化说明："
echo "    脚本已自动执行 conda init，重启终端后 conda 命令可用"
echo "    如果当前终端 conda 命令不可用，请执行: source ~/.bashrc"
echo ""
echo "环境控制："
echo "    conda config --set auto_activate_base false  # 禁用开机自动激活base环境"
echo "    conda config --set auto_activate_base true   # 启用开机自动激活base环境"
echo ""
echo "现在可以运行："
echo "    conda activate pyl      # 激活环境"
echo "    jupyter lab            # 启动 Jupyter Lab"
echo ""
echo "高级包安装："
echo "    bash optional-packages.sh"
