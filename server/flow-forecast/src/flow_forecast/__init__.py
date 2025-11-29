"""Flow Forecast API - USGS water flow forecasting service"""

__version__ = "0.1.0"


def main() -> None:
    """Entry point for running the Flow Forecast API server"""
    from flow_forecast.__main__ import main as _main

    _main()
