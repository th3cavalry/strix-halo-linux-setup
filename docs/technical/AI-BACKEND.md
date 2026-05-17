# AI Backend Documentation

## Overview

The GZ302 Linux Setup now includes AI backend support with **Lemonade SDK** as the default. Lemonade provides a unified API for local AI development with multi-backend support for NPU, GPU, and CPU acceleration.

## Default AI Backend: Lemonade SDK

Lemonade SDK is installed by default and provides:

- **OpenAI API Compatible** - Works with hundreds of existing AI applications without code changes
- **Multi-Engine Architecture** - Supports llama.cpp, Ryzen AI SW, FastFlowLM, whisper.cpp, stablediffusion.cpp, Kokoro
- **Multi-Modal Support** - Text generation, image generation, speech-to-text, text-to-speech, embeddings, reranking
- **Hardware Auto-Configuration** - Automatically configures NPU, GPU, and CPU backends for optimal performance
- **Cross-Platform** - Consistent experience across Windows, Linux, and macOS

### Hardware Requirements

Lemonade SDK works best on systems with:

- **AMD Ryzen AI processors** (Phoenix, Hawk Point, Strix, Strix Halo, Krackan Point)
- **AMD Radeon GPUs** (Radeon 7000 series and newer)
- **Any modern CPU** (for CPU fallback)

### Installation

Lemonade SDK is automatically installed during the main installation process. The installer:

1. Installs base dependencies (Python, pip, cmake, git, build-essential)
2. Installs Lemonade SDK via pip with AMD's custom PyPI index
3. Installs NPU drivers for Ryzen AI support
4. Installs Vulkan for GPU acceleration
5. Creates `/etc/strix-halo/ai/backend` file with the selected backend

### Usage

After installation, you can use Lemonade in several ways:

#### Command Line Interface

```bash
# List available models
lemonade list

# Start a chat session
lemonade chat

# Run Lemonade Server (OpenAI-compatible API)
lemonade server

# Download and manage models
lemonade models
```

#### Python API

```python
from lemonade.api import from_pretrained

model, tokenizer = from_pretrained(
    "amd/Llama-3.2-1B-Instruct-awq-g128-int4-asym-fp16-onnx-hybrid",
    recipe="oga-hybrid"
)

input_ids = tokenizer("This is my prompt", return_tensors="pt").input_ids
response = model.generate(input_ids, max_new_tokens=30)
print(tokenizer.decode(response[0]))
```

#### OpenAI-Compatible API

Lemonade Server provides an OpenAI-compatible endpoint:

```bash
# Start the server
lemonade server

# Use with any OpenAI-compatible client
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "amd/Llama-3.2-1B-Instruct",
    "messages": [{"role": "user", "content": "Hello!"}],
    "temperature": 0.7
  }'
```

## Alternative AI Backends

If you prefer a different AI backend, you can configure it during installation or after.

### Environment Variables

Set `AI_BACKEND` before running the installer:

```bash
# Use Lemonade (default)
sudo AI_BACKEND=lemonade bash strix-halo-setup.sh

# Use ROCm
sudo AI_BACKEND=rocm bash strix-halo-setup.sh

# Use CPU only
sudo AI_BACKEND=cpu bash strix-halo-setup.sh
```

### Supported Backends

| Backend | Description | Best For |
|---------|-------------|----------|
| `lemonade` | Unified API, OpenAI-compatible, multi-backend | Default choice, most features |
| `rocm` | AMD GPU compute stack | AMD GPU-focused workloads |
| `cpu` | Generic Python support | Systems without dedicated GPU/NPU |

### Post-Installation Backend Switching

To switch backends after installation:

1. Remove the current backend packages
2. Install the new backend packages
3. Update `/etc/strix-halo/ai/backend`:

```bash
echo "rocm" | sudo tee /etc/strix-halo/ai/backend
```

## Backend Comparison

### Lemonade SDK
- ✅ Unified API across all backends
- ✅ OpenAI-compatible out of the box
- ✅ Automatic hardware detection and optimization
- ✅ Multi-model support (text, image, speech)
- ✅ Cross-platform (Windows, Linux, macOS)
- ❌ Requires Python dependencies
- ❌ Larger installation footprint

### ROCm
- ✅ Direct AMD GPU access
- ✅ Optimized for AMD GPUs
- ✅ Lower-level control
- ❌ Linux-only
- ❌ Requires ROCm-compatible hardware
- ❌ More complex setup

### CPU Only
- ✅ Works on any system
- ✅ Minimal dependencies
- ✅ No GPU/NPU requirements
- ❌ Slower performance
- ❌ Limited model support
- ❌ No hardware acceleration

## Troubleshooting

### Lemonade Installation Issues

If Lemonade installation fails:

1. Check Python version: `python3 --version` (should be 3.8+)
2. Check pip: `pip3 --version`
3. Verify AMD PyPI index: `pip config list | grep extra-index-url`
4. Check for network issues: `curl https://pypi.amd.com/simple`

### Backend Detection

Lemonade automatically detects available hardware:

- **NPU**: AMD Ryzen AI processors (XDNA architecture)
- **GPU**: AMD Radeon GPUs (via Vulkan)
- **CPU**: Any modern CPU (fallback)

You can check what's available:

```bash
# Check NPU
npu-smi -l

# Check GPU
vulkaninfo --summary

# Check CPU
lscpu
```

### Model Loading Issues

If models fail to load:

1. Check available RAM (models need sufficient memory)
2. Verify model format (GGUF, ONNX, etc.)
3. Check model compatibility: `lemonade list`
4. Try a smaller model first

## Resources

- [Lemonade SDK Documentation](https://lemonade-sdk.ai)
- [AMD AI Developer Program](https://developer.amd.com/ai)
- [Lemonade GitHub Repository](https://github.com/lemonade-sdk)
- [Ryzen AI Software](https://www.amd.com/en/technologies/ryzen-ai.html)

## Version Information

- Lemonade SDK: Latest stable release (installed via pip)
- AI Backend Config: `/etc/strix-halo/ai/backend`
- Installation Date: Stored in installation logs
- GZ302 Setup Version: 4.2.0+
