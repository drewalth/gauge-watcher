"""Entry point for running the Flow Forecast API server"""

import asyncio

from hypercorn.asyncio import serve
from hypercorn.config import Config

from flow_forecast.app import app


def main() -> None:
    """Start the Flow Forecast API server"""
    config = Config()
    config.bind = ["0.0.0.0:8000"]
    asyncio.run(serve(app, config=config))


if __name__ == "__main__":
    main()
