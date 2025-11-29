from datetime import date
from typing import Optional

from pydantic import BaseModel, Field, field_validator


class USGSFlowForecastRequest(BaseModel):
    site_id: str = Field(
        description="The USGS site ID",
        json_schema_extra={"example": "01646500"},
        min_length=1,
    )
    reading_parameter: str = Field(
        description="The USGS reading parameter code",
        json_schema_extra={"example": "00060"},
        min_length=1,
    )
    start_date: Optional[date] = Field(
        default=None,
        description="The start date of the forecast",
        json_schema_extra={"example": "2023-01-01"},
    )
    end_date: Optional[date] = Field(
        default=None,
        description="The end date of the forecast",
        json_schema_extra={"example": "2024-12-31"},
    )

    @field_validator("site_id")
    @classmethod
    def validate_site_id(cls, v: str) -> str:
        """Validate that site_id is not empty and contains only valid characters"""
        if not v or not v.strip():
            raise ValueError("site_id cannot be empty")

        # USGS site IDs are typically 8-15 digits
        if not v.isdigit():
            raise ValueError("site_id must contain only digits")

        if len(v) < 8 or len(v) > 15:
            raise ValueError("site_id must be 8-15 digits long")

        return v

    @field_validator("reading_parameter")
    @classmethod
    def validate_reading_parameter(cls, v: str) -> str:
        """Validate that reading_parameter is not empty"""
        if not v or not v.strip():
            raise ValueError("reading_parameter cannot be empty")

        # USGS parameter codes are typically 5 digits
        if not v.isdigit():
            raise ValueError("reading_parameter must contain only digits")

        if len(v) != 5:
            raise ValueError(
                "reading_parameter must be 5 digits (e.g., 00060 for discharge)"
            )

        return v

    @field_validator("end_date")
    @classmethod
    def validate_date_range(cls, v: Optional[date], info) -> Optional[date]:
        """Validate that end_date is after start_date if both are provided"""
        if v is not None and "start_date" in info.data:
            start_date = info.data["start_date"]
            if start_date is not None and v < start_date:
                raise ValueError("end_date must be after start_date")

        return v
