import datetime as dt
import logging
from typing import List

from fastapi import APIRouter, HTTPException, status

from ..model.forecast_result import ForecastDataPoint
from ..model.usgs import USGSFlowForecastRequest
from ..utils import format_output
from .service import generate_prophet_forecast

log = logging.getLogger(__name__)

usgs_router = APIRouter(
    prefix="/usgs",
    tags=["usgs"],
    responses={404: {"description": "Not found"}},
)


@usgs_router.post(
    "/forecast",
    response_model=List[ForecastDataPoint],
    responses={
        400: {"description": "Invalid request parameters"},
        500: {"description": "Internal server error"},
        502: {"description": "Error communicating with USGS API"},
    },
)
async def forecast(
    request: USGSFlowForecastRequest,
) -> List[ForecastDataPoint]:
    """Generate flow forecast for a USGS site

    Args:
        request: Forecast request with site_id, reading_parameter, and optional date range

    Returns:
        List of forecast data points with historical and predicted values

    Raises:
        HTTPException: Various error conditions (400, 500, 502)
    """
    log.info(
        f"Forecast request for site {request.site_id}, parameter {request.reading_parameter}"
    )

    # Set default dates to current year if not provided
    today = dt.date.today()
    start_date = request.start_date if request.start_date else dt.date(today.year, 1, 1)
    end_date = request.end_date if request.end_date else dt.date(today.year, 12, 31)

    try:
        forecast_result = format_output(
            generate_prophet_forecast(
                request.site_id, request.reading_parameter, start_date, end_date
            )
        )

        log.info(
            f"Successfully generated forecast with {len(forecast_result)} data points"
        )
        return forecast_result

    except ValueError as e:
        log.warning(f"Invalid request parameters: {e}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Invalid request: {str(e)}",
        )
    except ConnectionError as e:
        log.error(f"Failed to connect to USGS API: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"Failed to fetch data from USGS API: {str(e)}",
        )
    except KeyError as e:
        log.error(f"Unexpected USGS API response structure: {e}")
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Received unexpected response from USGS API",
        )
    except Exception as e:
        log.error(f"Unexpected error generating forecast: {e}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="An unexpected error occurred while generating the forecast",
        )
