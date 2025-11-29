import asyncio

from hypercorn.asyncio import serve
from hypercorn.config import Config

from flow_forecast.app import app

config = Config()
config.bind = ["0.0.0.0:8000"]
asyncio.run(serve(app, config=config))



# def main() -> None:
#     print("Hello from flow-forecast!")
