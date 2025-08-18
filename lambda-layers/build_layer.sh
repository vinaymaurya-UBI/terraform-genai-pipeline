#!/bin/bash
mkdir -p python
pip install -r requirements.txt -t python/
zip -r embedding-layer.zip python/
rm -rf python/
