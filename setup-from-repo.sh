#!/bin/bash
# 运行: 克隆仓库后恢复环境和 Jupyter
# 用法: bash setup_from_repo.sh

set -e
cd $(dirname $0)

# -------------------------------
# Step 0: 更新系统
# -------------------------------
echo "[0] 更新系统软件..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y wget git curl build-essential

# -------------------------------
# Step 1: 检查 conda, 没有则安装 Miniconda
# -------------------------------
if ! command -v conda &> /dev/null; then
  echo "[1] 未检测到 conda, 正在安装 Miniconda..."
  wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh
  bash ~/miniconda.sh -b -p $HOME/miniconda
  rm ~/miniconda.sh
  eval "$($HOME/miniconda/bin/conda shell.bash hook)"
  conda init bash
  echo "[1] Miniconda 安装完成"
else
  echo "[1] 已检测到 conda"
  eval "$(conda shell.bash hook)"
fi

# -------------------------------
# Step 2: 更新 conda 和 pip
# -------------------------------
echo "[2] 更新 conda & pip"
conda update -n base -c defaults -y conda
python -m pip install --upgrade pip setuptools wheel

# -------------------------------
# Step 3: 创建 pyl 环境
# -------------------------------
echo "[3] 创建 conda 环境 pyl"
conda env create -f conda-envs/pyl.from-history.yml || \
conda env create -f conda-envs/pyl.no-builds.yml

# -------------------------------
# Step 4: 安装 pip 包
# -------------------------------
echo "[4] 安装 pip 包"
conda activate pyl
pip install --upgrade pip setuptools wheel
pip install -r conda-envs/pyl.pip-freeze.txt
conda deactivate

# -------------------------------
# Step 5: 恢复 Jupyter & JupyterLab 配置
# -------------------------------
echo "[5] 恢复 Jupyter 配置"
tar xzf jupyter/jupyter-config.tgz -C ~/
tar xzf jupyter/jupyterlab-config.tgz -C ~/.local/share/ || true

# -------------------------------
# Step 6: 注册 Jupyter kernel
# -------------------------------
echo "[6] 注册 Jupyter kernel"
conda activate pyl
python -m ipykernel install --user --name pyl --display-name "Python (pyl)"
conda deactivate

# -------------------------------
# Step 7: 检查
# -------------------------------
echo "[7] 检查环境和内核"
conda info --envs
jupyter kernelspec list

echo "✅ 环境恢复完成！"
echo "你现在可以运行: conda activate pyl && jupyter lab"

