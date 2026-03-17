## Setup

- Install `mise`
- Run `mise install`

## Mac llama.cpp setup 
We have a simple download and build script
`%> ./tools/llamacpp/download-build.sh`
It will build and install it in the ~/llama.cpp directory

This uses a huggingface module internally. Set a cache directory and download workers
```
export LLAMA_CACHE=~/models/hf
export HF_HUB_DOWNLOAD_MAX_WORKERS=8
```

Then you can start up llamacpp server like this (note do on a 48GB RAM M4 Pro)
`llama-server -hf Qwen/Qwen2.5-32B-Instruct-GGUF:Q5_K_M --port 8111 -ngl 99`

## Mac vLLM-Metal setup
### [Copy of setup instructions from Michael Hannecke](https://medium.com/@michael.hannecke/hands-on-vllm-metal-on-mac-studio-m4-6263062c8c2d)


### The Careful Way (Don’t Pipe to Bash)
The official docs tell you to run:

`curl -fsSL https://raw.githubusercontent.com/vllm-project/vllm-metal/main/install.sh | bash`
We’re going to do it differently. Download first, read it, then run it.

```
%> ./tools/vllm/download.sh
# downloads to ~/vllm-metal-setup
```

Now read the scripts:

```
less ~/vllm-metal-setup/install.sh   # About 90 lines. It's not scary.
less ~/vllm-metal-setup/lib.sh       # Helper functions. Even less scary.
```

Things to look for: unexpected network calls, sudo usage, file modifications outside the venv. You should find none of these. If you’re satisfied:

`bash install.sh`

This takes 5–15 minutes. Go get coffee. When it’s done:

`Installation complete!`

Note on vLLM versions: The installer builds vLLM 0.13.0 from source (pinned by vllm-metal for stability). The vLLM mainline is at v0.15.1 as of February 2026, but vllm-metal requires the older version. The vllm-metal plugin itself is at v0.1.0.

Verify the Installation
```
%> ./tools/vllm/activate.sh
```

If any of the tests fail, stop. Fix the issue before continuing.

Freeze Your Environment
```
uv pip freeze > ~/vllm-metal-setup/requirements-frozen.txt
shasum -a 256 ~/vllm-metal-setup/requirements-frozen.txt > ~/vllm-metal-setup/requirements-frozen.sha256
```

## Serving a model
We just need the model name and the port
`%> ./tools/vllm/serve.sh <port> <model>`

For example: `./tools/vllm/serve 8111 mlx-community/Llama-3.2-3B-8bit`

It will download if it's not there and eventually be ready to startup. Should see something like
```
(APIServer pid=75553) INFO:     Waiting for application startup.
(APIServer pid=75553) INFO:     Application startup complete.
```
Test it by doing `curl http://localhost:8111/health` or `curl http://localhost:8111/v1/models`. Change the hostname and port as needed. For health and models you should see `200 OK` logged by vllm. For the model call you should see JSON output like
```
{
  "object": "list",
  "data": [
    {
      "id": "mlx-community/Llama-3.2-3B-bf16",
      "object": "model",
      "created": 1773731221,
      "owned_by": "vllm",
      "root": "mlx-community/Llama-3.2-3B-bf16",
      "parent": null,
      "max_model_len": 131072,
      "permission": [
        {
          "id": "modelperm-83ab6dea8fe01e9e",
          "object": "model_permission",
          "created": 1773731221,
          "allow_create_engine": false,
          "allow_sampling": true,
          "allow_logprobs": true,
          "allow_search_indices": false,
          "allow_view": true,
          "allow_fine_tuning": false,
          "organization": "*",
          "group": null,
          "is_blocking": false
        }
      ]
    }
  ]
}
```

## Setting up LangChain and LangGraph
Make sure using the right python via mise

Use pip to install
`pip install langgraph langchain-openai`