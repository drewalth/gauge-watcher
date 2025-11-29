# Server

While the goal is to do everything on the user's device, there are some things that are better executed by a server-side solution.

For forecasting, I'd like to try on-device `FoundationModels` and `CoreML` models, but till now, I haven't found a great way to do it.

So, for now, we'll use a server-side solution.

## Flow Forecast

The flow forecast server is a FastAPI application that provides a REST API for forecasting flow data using the `prophet` library.

This service uses FastAPI's auto-generated OpenAPI schema to generate a Swift client for the app to use.

### Running the Server

```bash
cd server/flow-forecast
uv run flow-forecast
```

### Generating the Swift Client

> TODO: make this process a little less manual.

