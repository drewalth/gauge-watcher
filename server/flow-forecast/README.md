# Flow Forecast

This is a total rewrite of [github.com/drewalth/flow-forecast](https://github.com/drewalth/flow-forecast) using [UV](https://docs.astral.sh/uv/) and [FastAPI](https://fastapi.tiangolo.com/). 

It addresses several issues with the original implementation:

- It adds better error handling and logging.
- It adds better memory management for running in resource-constrained environments.