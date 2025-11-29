from fastapi import FastAPI, Request
import logging
import time

from .router.router import app_router
from .usgs.router import usgs_router

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(name)s] %(levelname)s: %(message)s",
)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Flow Forecast API",
    description="API for forecasting water flow data using the USGS API",
    version="0.1.0",
    license={
        "name": "MIT License",
        "url": "https://opensource.org/licenses/MIT",
    },
    servers=[
        {"url": "http://localhost:8000", "description": "Development"},
    ]
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    start_time = time.perf_counter()
    response = await call_next(request)
    response_time = time.perf_counter() - start_time
    logger.info(
        f"{request.method} {request.url.path} {response.status_code} {response_time:.3f}s"
    )
    return response


app.include_router(app_router)
app.include_router(usgs_router)


@app.get("/", include_in_schema=False)
async def root() -> dict[str, str]:
    return {"message": "Flow Forecast API is running"}
