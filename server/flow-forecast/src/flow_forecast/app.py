from fastapi import FastAPI

from .router.router import app_router
from .usgs.router import usgs_router

app = FastAPI()

app.include_router(app_router)
app.include_router(usgs_router)


@app.get("/", include_in_schema=False)
async def root() -> dict[str, str]:
    return {"message": "Flow Forecast API is running"}
