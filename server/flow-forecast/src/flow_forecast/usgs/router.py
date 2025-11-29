import datetime as dt
from typing import List

from fastapi import APIRouter

from ..model.forecast_result import ForecastDataPoint
from ..model.usgs import USGSFlowForecastRequest
from ..utils import format_output
from .service import generate_prophet_forecast

usgs_router = APIRouter(
    prefix="/usgs",
    tags=["usgs"],
    responses={404: {"description": "Not found"}},
)


@usgs_router.post("/forecast")
async def forecast(
    request: USGSFlowForecastRequest,
) -> List[ForecastDataPoint]:

    start_date = request.start_date if request.start_date else dt.date(dt.date.today().year, 1, 1)
    end_date = request.end_date if request.end_date else dt.date(dt.date.today().year, 12, 31)

    forecast_result = format_output(generate_prophet_forecast(request.site_id, request.reading_parameter, start_date, end_date))

    return forecast_result
