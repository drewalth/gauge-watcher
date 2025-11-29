import datetime
import datetime as dt
import json
import logging

import numpy as np
import pandas as pd
import urllib3
from prophet import Prophet

base_usgs_url = "http://waterservices.usgs.gov/nwis/dv/?format=json"

log = logging.getLogger(__name__)
log.setLevel(logging.DEBUG)


def get_daily_average_data(
    site_id: str,
    reading_parameter: str,
    start_date: datetime.date,
    end_date: datetime.date,
) -> list[dict]:
    """Calls USGS api to get daily average values in the given date range

    Raises:
        ValueError: If site_id or reading_parameter are invalid
        ConnectionError: If USGS API is unreachable
        KeyError: If API response structure is unexpected
    """
    if not site_id or not site_id.strip():
        raise ValueError("site_id cannot be empty")

    if not reading_parameter or not reading_parameter.strip():
        raise ValueError("reading_parameter cannot be empty")

    url = f"{base_usgs_url}&site={site_id}&startDT={start_date}&endDT={end_date}&parameterCd={reading_parameter}"  # noqa: E501

    log.info(f"Fetching USGS data for site {site_id}, parameter {reading_parameter}")

    try:
        http = urllib3.PoolManager(timeout=urllib3.Timeout(connect=10.0, read=30.0))
        response = http.request("GET", url)

        if response.status != 200:
            log.error(f"USGS API returned status {response.status}")
            raise ConnectionError(
                f"USGS API request failed with status {response.status}"
            )

        response_json = json.loads(response.data.decode("utf-8"))

        # Validate response structure
        if "value" not in response_json:
            log.error(f"Unexpected API response structure: missing 'value' key")
            raise KeyError("API response missing 'value' field")

        time_series = response_json["value"].get("timeSeries", [])
        if not time_series or len(time_series) == 0:
            log.warning(f"No time series data found for site {site_id}")
            return []

        values = time_series[0].get("values", [])
        if not values or len(values) == 0:
            log.warning(f"No values found in time series for site {site_id}")
            return []

        data = values[0].get("value", [])
        log.info(f"Successfully fetched {len(data)} data points")
        return data

    except json.JSONDecodeError as e:
        log.error(f"Failed to parse USGS API response as JSON: {e}")
        raise ValueError(f"Invalid JSON response from USGS API: {e}")
    except urllib3.exceptions.HTTPError as e:
        log.error(f"HTTP error connecting to USGS API: {e}")
        raise ConnectionError(f"Failed to connect to USGS API: {e}")
    except Exception as e:
        log.error(f"Unexpected error fetching USGS data: {e}")
        raise


# DELETED: clean_data() was identical to get_cleaned_data() below
# This was technical debt - two functions doing the exact same thing


def format_season_average_data(json_data: dict) -> pd.DataFrame:
    """Given USGS data, cleans the data and formats to display seasonal averages"""

    data_frame = pd.DataFrame(json_data)
    data_frame = data_frame.drop("qualifiers", axis=1)
    data_frame["value"] = data_frame["value"].astype(float)
    data_frame["dateTime"] = pd.to_datetime(data_frame["dateTime"])
    months, days, years = zip(
        *[(d.month, d.day, d.year) for d in data_frame["dateTime"]]
    )
    data_frame = data_frame.assign(month=months, day=days, year=years)
    data_frame = data_frame.drop("dateTime", axis=1)
    data_frame = data_frame.pivot(
        index=["month", "day"], columns="year", values="value"
    )
    data_frame.index = data_frame.index.map(lambda t: f"{t[0]}/{t[1]}")
    data_frame[data_frame <= 0] = np.nan
    return data_frame


current_year = dt.date.today().year
# Only train forecast from data from the last x years.
# This *should* be a parameter that can be set by the user, but for now we'll hardcode it.
x_years_ago = current_year - 5

start_date = dt.date(x_years_ago, 1, 1)


def generate_prophet_forecast(
    site_id: str, reading_parameter: str, start_date: dt.date, end_date: dt.date
) -> pd.DataFrame:
    """Given a site, model, and length, returns a forecast DataFrame using fbprophet

    Args:
        site_id: USGS site identifier
        reading_parameter: USGS parameter code (e.g., '00060' for discharge)
        start_date: Start date for historical data
        end_date: End date for forecast

    Returns:
        DataFrame with past_value, forecast, and error bounds indexed by date (M/D format)

    Raises:
        ValueError: If no data available or date range is invalid
    """
    log.info(f"Generating forecast for site {site_id} from {start_date} to {end_date}")

    # Fetch and clean data
    site_data = get_daily_average_data(
        site_id=site_id,
        reading_parameter=reading_parameter,
        start_date=start_date,
        end_date=end_date,
    )

    if not site_data:
        raise ValueError(f"No data available for site {site_id}")

    clean_data = get_cleaned_data(site_data)

    if clean_data.empty:
        raise ValueError(f"No valid data after cleaning for site {site_id}")

    clean_data.columns = ["ds", "y"]

    # Generate forecast for remaining days in current year
    forecast_df = generate_forecast(clean_data)

    # Filter historic data to current year only
    today = dt.date.today()
    current_year_start = dt.datetime(today.year, 1, 1)
    historic_df = clean_data[clean_data["ds"] >= current_year_start].copy()
    historic_df = historic_df.drop("ds", axis=1)
    historic_df.columns = ["past_value"]

    forecast_df.columns = ["forecast", "lower_error_bound", "upper_error_bound"]

    # Concatenate historic and forecast data
    final_df = pd.concat([historic_df, forecast_df], ignore_index=True)

    # Create date range for current year
    year_start = dt.date(today.year, 1, 1)
    year_end = dt.date(today.year, 12, 31)
    dates = pd.date_range(start=year_start, end=year_end)

    # Validate that we have the right amount of data
    if len(final_df) != len(dates):
        log.warning(
            f"Data length mismatch: {len(final_df)} rows but {len(dates)} days in year. "
            f"Historic: {len(historic_df)}, Forecast: {len(forecast_df)}"
        )

        # Pad or trim to match year length
        if len(final_df) < len(dates):
            # Pad with NaN rows
            padding_needed = len(dates) - len(final_df)
            padding_df = pd.DataFrame(
                {col: [np.nan] * padding_needed for col in final_df.columns}
            )
            final_df = pd.concat([final_df, padding_df], ignore_index=True)
        else:
            # Trim excess rows
            final_df = final_df.iloc[: len(dates)]

    final_df.index = [date.strftime("%-m/%-d") for date in dates]

    log.info(f"Generated forecast with {len(final_df)} data points")
    return final_df


def get_cleaned_data(json_data: list[dict]) -> pd.DataFrame:
    """Given usgs json data, cleans the data and returns a DataFrame

    Args:
        json_data: List of dicts with 'dateTime', 'value', and 'qualifiers' keys

    Returns:
        DataFrame with 'dateTime' and 'value' columns, invalid values replaced with NaN

    Raises:
        ValueError: If json_data is empty or missing required fields
    """
    if not json_data:
        log.warning("Received empty data for cleaning")
        raise ValueError("Cannot clean empty data")

    try:
        data_frame = pd.DataFrame(json_data)

        # Validate required columns exist
        required_cols = ["dateTime", "value", "qualifiers"]
        missing_cols = [col for col in required_cols if col not in data_frame.columns]
        if missing_cols:
            raise ValueError(f"Missing required columns: {missing_cols}")

        data_frame = data_frame.drop("qualifiers", axis=1)
        data_frame["value"] = data_frame["value"].astype(float)
        data_frame["dateTime"] = pd.to_datetime(data_frame["dateTime"])
        data_frame.set_index("dateTime", inplace=True)
        data_frame = data_frame.asfreq("d")  # adds missing day data
        data_frame.loc[data_frame["value"] <= 0, "value"] = np.nan
        data_frame = data_frame.reset_index()
        data_frame = data_frame[["dateTime", "value"]]

        log.info(
            f"Cleaned data: {len(data_frame)} rows, {data_frame['value'].notna().sum()} valid values"
        )
        return data_frame

    except (ValueError, TypeError) as e:
        log.error(f"Failed to clean data: {e}")
        raise ValueError(f"Data cleaning failed: {e}")
    except Exception as e:
        log.error(f"Unexpected error during data cleaning: {e}")
        raise


def generate_forecast(historic_data: pd.DataFrame) -> pd.DataFrame:
    """Takes in a training set (data - value) and a length to
    return a forecast DataFrame"""

    # historic_data = historic_data.ffill()  # Fill missing values for a better forecast
    # historic_data = historic_data.bfill()

    model = Prophet(interval_width=0.50)

    model.fit(historic_data)
    forecast = model.predict(
        model.make_future_dataframe(
            periods=get_forecast_length(historic_data.iloc[-1]["ds"].date()),
            include_history=False,
        )
    )
    forecast = forecast.round()

    return forecast[["yhat", "yhat_lower", "yhat_upper"]]


def get_forecast_length(last_data_day: dt.date) -> int:
    first_forecast_date = last_data_day + dt.timedelta(days=1)
    return pd.date_range(
        start=first_forecast_date, end=dt.date(first_forecast_date.year, 12, 31)
    ).size  # get number of remaining dates in the year including 'today'
