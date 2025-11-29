from pydantic import BaseModel, Field
from datetime import date
from typing import Optional

class USGSFlowForecastRequest(BaseModel):
    site_id: str = Field(description="The USGS site ID", example="01646500")
    reading_parameter: str = Field(description="The USGS reading parameter", example="00060")
    start_date: Optional[date] = Field(description="The start date of the forecast", example=date(2023, 1, 1))
    end_date: Optional[date] = Field(description="The end date of the forecast", example=date(2024, 12, 31))