# 🚀 Deep Learning Jupyter Environment (dl-jupyter)

一个开箱即用的深度学习环境自动化安装脚本，适用于 Ubuntu 系统。

## ✨ 特性

- 🎯 **智能环境检测** - 自动检测 GPU 并选择合适的 PyTorch 版本
- 📦 **分步安装策略** - 单个包失败不影响整体安装流程
- 🔧 **容错机制** - 提供详细的失败包汇总和手动安装指导
- 📚 **深度学习友好** - 预装 d2l (Dive into Deep Learning) 等重要包
- 🎨 **可选扩展** - 额外的高级包可按需安装

## 🚀 快速开始

### 1. 克隆项目

#### github 请使用：

```bash
git clone https://github.com/winbeau/dl-jupyter.git
cd dl-jupyter
```

#### gitee 请使用
```bash
git clone https://gitee.com/winbeau/dl-jupyter.git
cd dl-jupyter
```

#### * 若首次使用 Ubuntu 请运行以下命令初始化系统
```bash
su -i # 切换至管理员
```

切换至管理员后目录也会被切换`(home/<username> -> root/)` <br>

所以需要再执行一遍步骤1

```bash
bash init_env.sh
```

> **注意**
> 环境初始化脚本会重新注册用户<br>
> 若用户名重复，脚本会卡住 需要 `Ctrl + C` 手动退出，再执行一遍 `bash` 操作即可<br>
> *删除用户名操作:* `sudo deluser username`


### 2. 运行核心安装

```bash
chmod +x setup-core.sh
bash setup-core.sh
```

### 3. 激活环境

```bash
conda activate pyl
jupyter lab
```

### 4. 安装可选高级包 (可选)

```bash
bash optional-packages.sh
```

## 📋 安装的核心包

### 基础环境
- Python 3.10
- Jupyter Lab & Notebook
- IPython Kernel

### 深度学习
- PyTorch (自动选择 CUDA/CPU 版本)
- TorchVision & TorchAudio  
- D2L (Dive into Deep Learning)

### 科学计算
- NumPy, Pandas, SciPy
- Matplotlib, Seaborn
- Scikit-learn
- OpenCV, Pillow

### 开发工具
- TQDM (进度条)
- IPython Widgets
- Node.js, Yarn

## 📁 项目结构

```
dl-setup/
├── README.md                 # 项目说明文档
├── setup-core.sh             # 主安装脚本
├── optional-packages.sh      # 可选包安装脚本
└── conda-envs/
    └── pyl.core.yml          # 核心环境配置文件
```

## ⚙️ 安装流程

```
[1] 更新系统软件
[2] 安装 Miniconda (如未安装)
[3] 配置 Anaconda ToS 和镜像源
[4] 创建核心 Python 环境
[5] 智能安装 PyTorch (GPU/CPU 自适应)
[6] 安装 d2l (深度学习教程包)
[7] 逐步安装科学计算包
[8] 注册 Jupyter 内核
[9] 环境验证和失败包汇总
```

## 🎯 GPU 支持

脚本会自动检测系统中的 NVIDIA GPU：

- **有 GPU**: 安装 CUDA 版 PyTorch (CUDA 11.8)
- **无 GPU**: 安装 CPU 版 PyTorch

## 📊 可选高级包

运行 `optional-packages.sh` 可安装：

- **深度学习**: transformers, datasets, accelerate
- **数据可视化**: plotly, bokeh, altair  
- **网络爬虫**: requests, beautifulsoup4, scrapy
- **图像处理**: scikit-image, imageio
- **自然语言处理**: nltk, spacy, gensim
- **数据库**: sqlalchemy, psycopg2-binary, pymongo
- **统计分析**: statsmodels

## 🛠️ 故障排除

### 如果安装失败

脚本会显示失败包汇总，例如：

```
⚠️  安装失败的包汇总 (2个)：
----------------------------------------
  ❌ PyTorch (CUDA) (conda: pytorch pytorch-cuda=11.8...)
  ❌ OpenCV (pip: opencv-python)
----------------------------------------

💡 你可以稍后手动安装这些包：
   conda activate pyl
   conda install pytorch pytorch-cuda=11.8 torchvision torchaudio -c pytorch -c nvidia
   pip install opencv-python
```

### 常见问题

1. **网络问题**: 脚本使用清华镜像源，如仍有问题可手动更换镜像
2. **权限问题**: 确保有 sudo 权限用于系统软件安装
3. **磁盘空间**: 确保有足够空间（建议 5GB+ 可用空间）

## 🔧 自定义配置

### 修改 Python 版本

编辑 `conda-envs/pyl.core.yml`:

```yaml
dependencies:
  - python=3.11  # 改为你需要的版本
```

### 添加自定义包

编辑脚本中的安装部分，或在 `optional-packages.sh` 中添加。

## 📚 使用场景

- 🎓 **深度学习课程** - 适合《动手学深度学习》等课程
- 🔬 **科研环境** - 完整的科学计算和机器学习工具链  
- 👨‍💻 **开发环境** - 快速搭建 ML/DL 项目环境
- 🏫 **教学环境** - 批量部署标准化学习环境

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！


---

**快速启动命令:**

```bash
git clone https://github.com/winbeau/dl-jupyter.git && cd dl-setup && bash setup-core.sh
```

**安装完成后:**

```bash
conda activate pyl && jupyter lab
```

---

## 联系方式
作者: winbeau | 邮箱: geneva4869@163.com
