#!/usr/bin/env bash
# 可选包安装脚本 - 在核心环境建好后运行

set -e
eval "$($HOME/miniconda/bin/conda shell.bash hook)"
conda activate pyl

echo "安装可选的高级包..."

# 深度学习相关
echo "→ 深度学习包"
pip install transformers datasets accelerate || echo "  ✗ transformers 相关包安装失败"

# 数据可视化
echo "→ 高级可视化包"
pip install plotly bokeh altair || echo "  ✗ 高级可视化包安装失败"

# 网络爬虫
echo "→ 爬虫相关包"
pip install requests beautifulsoup4 scrapy || echo "  ✗ 爬虫包安装失败"

# 图像处理
echo "→ 图像处理包"
pip install scikit-image imageio || echo "  ✗ 图像处理包安装失败"

# 自然语言处理
echo "→ NLP 包"
pip install nltk spacy gensim || echo "  ✗ NLP 包安装失败"

# 数据库连接
echo "→ 数据库包"
pip install sqlalchemy psycopg2-binary pymongo || echo "  ✗ 数据库包安装失败"

# 统计分析
echo "→ 统计包"
pip install statsmodels || echo "  ✗ 统计包安装失败"

echo "✓ 可选包安装完成"
