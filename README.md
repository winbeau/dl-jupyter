# 深度学习环境复现（pyl）

本仓库用于将我的深度学习开发环境（conda + jupyter lab + 扩展配置）迁移到另一台 Ubuntu 机器上。  
同学只需 **clone 仓库** 并运行脚本，就能恢复与我一致的环境。

---

## 环境说明
- 系统：Ubuntu 22.04（WSL / 原生均可）
- 包管理：conda（自动安装 Miniconda）
- 环境名称：`pyl`
- 配套工具：jupyter, jupyter lab, ipykernel, 常用扩展

---

## 使用方法

### 1. 克隆仓库
```bash
git clone https://github.com/winbeau/dl-jupyter.git
cd dl-jupyter
```

### 2. 运行核心安装脚本
```bash
bash setup-core.sh
```

### 3. 如需安装可选包
```bash
bash optional-packages.sh
```

### 4. 激活环境并启动 Jupyter Lab
```bash
conda activate pyl
jupyter lab
```

---

## 仓库结构

```
.
├── conda-envs/ # conda 环境相关文件
│ ├── pyl.from-history.yml # 根据 conda history 导出的环境文件
│ ├── pyl.no-builds.yml # 无 build 号的环境文件（兼容性更好）
│ └── pyl.pip-freeze.txt # pip 包列表（保证一致性）
│
├── jupyter/ # Jupyter 配置文件
│ ├── jupyter-config.tgz # Jupyter 基础配置压缩包
│ └── jupyterlab-config.tgz # JupyterLab 配置（主题、扩展等）
│
├── setup_from_repo.sh # 一键恢复脚本
├── export_env.sh # 导出环境脚本
└── README.md # 使用说明（本文件）
```

## 脚本说明

`setup_from_repo.sh` 会自动执行以下步骤：

1. **更新系统软件**
`
sudo apt update && sudo apt upgrade -y
`

2. **安装 Miniconda（如未安装）**
自动下载并安装到 ~/miniconda

3. **更新 conda / pip**
确保使用最新版本，避免兼容性问题

4. **恢复 conda 环境**
根据仓库中的 `conda-envs/pyl.*.yml` 文件创建环境

5. **安装 pip 包**
使用 `pip-freeze.txt` 保证一致性

6. **恢复 Jupyter / JupyterLab 配置**

7. **注册内核**
将 `pyl` 环境注册到 Jupyter

---

## 验证

安装完成后，检查环境是否可用：

```bash
conda info --envs
jupyter kernelspec list
```

应当能看到 `pyl` 环境和对应的 Jupyter 内核。

---

## 注意事项

- 初次运行脚本需要网络环境较好（需下载 Miniconda 和依赖包）。

- 如果运行中断，可重新执行 `bash setup_from_repo.sh`。

---

## 联系方式

作者: **winbeau** | 
邮箱: geneva4869@163.com

---
