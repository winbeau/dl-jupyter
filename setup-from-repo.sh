#!/usr/bin/env bash
set -e

echo "[0] 开始执行环境恢复脚本"

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
# Step 6: 创建 pyl 环境
# ================================
echo "[6] 检测 GPU 类型..."
if command -v nvidia-smi &> /dev/null; then
    echo "[5] 检测到 NVIDIA GPU → 使用 GPU 版环境"
    if ! conda env create -f conda-envs/pyl.cuda.yml; then
        echo "[5-warning] GPU 环境创建失败，尝试 CPU 版..."
        conda env create -f conda-envs/pyl.cpu.yml || {
            echo "[5-error] CPU/GPU 环境均失败，创建最小环境"
            conda create -n pyl python=3.10 -y
        }
    fi
else
    echo "[6] 未检测到 NVIDIA GPU → 使用 CPU 版环境"
    if ! conda env create -f conda-envs/pyl.cpu.yml; then
        echo "[5-warning] CPU 环境失败，创建最小环境"
        conda create -n pyl python=3.10 -y
    fi
fi

# ================================
# Step 7: 激活环境 & 补充 pip 包
# ================================
echo "[7] 激活 pyl 环境..."
conda activate pyl

if [ -f conda-envs/pyl.pip-freeze.txt ]; then
    echo "[6] 安装 pip 包..."
    pip install -r conda-envs/pyl.pip-freeze.txt || true
fi

# ================================
# Step 8: 恢复 Jupyter 配置
# ================================
echo "[8] 恢复 Jupyter 配置..."
mkdir -p ~/.jupyter
if [ -f jupyter/jupyter-config.tgz ]; then
    tar -xzf jupyter/jupyter-config.tgz -C ~/
fi
if [ -f jupyter/jupyterlab-config.tgz ]; then
    tar -xzf jupyter/jupyterlab-config.tgz -C ~/
fi

# ================================
# Step 9: 注册 Jupyter 内核
# ================================
echo "[9] 注册 Jupyter 内核..."
python -m ipykernel install --user --name=pyl --display-name "Python (pyl)" || true

# ================================
# 完成
# ================================
echo "[✔] 环境恢复完成！"
echo "现在可以运行："
echo "    conda activate pyl"
echo "    jupyter lab"

