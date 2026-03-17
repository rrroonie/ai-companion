## Setup

- Install `mise`
- Run `mise install`

## Mac llama.cpp setup
We have a simple download and build script
`%> ./tools/llamacpp/download-build.sh`
It will build and install it in the ~/llama.cpp directory

To download a model use `hf`
```
brew install hf
hf download --local-dir ~/models/hf meta-llama/Llama-3.2-3B-Instruct
```

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