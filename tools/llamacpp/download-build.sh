#!/bin/bash
brew install cmake
rm -rf ~/llama.cpp
git clone https://github.com/ggerganov/llama.cpp.git ~/llama.cpp

# build
cd ~/llama.cpp
cmake -B build
cmake --build build --config Release -j