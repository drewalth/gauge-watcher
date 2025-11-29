"""Entry point for running the Flow Forecast API server"""

import asyncio

from hypercorn.asyncio import serve
from hypercorn.config import Config as HypercornConfig

from flow_forecast.app import app
from flow_forecast.config import config


def main() -> None:
    """Start the Flow Forecast API server"""
    app_config = HypercornConfig()
    app_config.bind = [f"{config.host}:{config.port}"]
    asyncio.run(serve(app, config=app_config))


if __name__ == "__main__":
    main()
