# UsgsAPI

All URIs are relative to *http://localhost*

Method | HTTP request | Description
------------- | ------------- | -------------
[**forecastUsgsForecastPost**](UsgsAPI.md#forecastusgsforecastpost) | **POST** /usgs/forecast | Forecast


# **forecastUsgsForecastPost**
```swift
    open class func forecastUsgsForecastPost(uSGSFlowForecastRequest: USGSFlowForecastRequest, completion: @escaping (_ data: [ForecastDataPoint]?, _ error: Error?) -> Void)
```

Forecast

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import FlowForecast

let uSGSFlowForecastRequest = USGSFlowForecastRequest(siteId: "siteId_example", readingParameter: "readingParameter_example", startDate: Date(), endDate: Date()) // USGSFlowForecastRequest | 

// Forecast
UsgsAPI.forecastUsgsForecastPost(uSGSFlowForecastRequest: uSGSFlowForecastRequest) { (response, error) in
    guard error == nil else {
        print(error)
        return
    }

    if (response) {
        dump(response)
    }
}
```

### Parameters

Name | Type | Description  | Notes
------------- | ------------- | ------------- | -------------
 **uSGSFlowForecastRequest** | [**USGSFlowForecastRequest**](USGSFlowForecastRequest.md) |  | 

### Return type

[**[ForecastDataPoint]**](ForecastDataPoint.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: application/json
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

