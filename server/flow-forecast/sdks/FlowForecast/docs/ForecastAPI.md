# ForecastAPI

All URIs are relative to *http://localhost:8000*

Method | HTTP request | Description
------------- | ------------- | -------------
[**forecastForecastGet**](ForecastAPI.md#forecastforecastget) | **GET** /forecast | Forecast


# **forecastForecastGet**
```swift
    open class func forecastForecastGet(siteId: String, readingParameter: String? = nil, startDate: Date? = nil, endDate: Date? = nil, completion: @escaping (_ data: [ForecastDataPoint]?, _ error: Error?) -> Void)
```

Forecast

### Example
```swift
// The following code samples are still beta. For any issue, please report via http://github.com/OpenAPITools/openapi-generator/issues/new
import FlowForecast

let siteId = "siteId_example" // String | 
let readingParameter = "readingParameter_example" // String |  (optional) (default to "00060")
let startDate = Date() // Date |  (optional)
let endDate = Date() // Date |  (optional)

// Forecast
ForecastAPI.forecastForecastGet(siteId: siteId, readingParameter: readingParameter, startDate: startDate, endDate: endDate) { (response, error) in
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
 **siteId** | **String** |  | 
 **readingParameter** | **String** |  | [optional] [default to &quot;00060&quot;]
 **startDate** | **Date** |  | [optional] 
 **endDate** | **Date** |  | [optional] 

### Return type

[**[ForecastDataPoint]**](ForecastDataPoint.md)

### Authorization

No authorization required

### HTTP request headers

 - **Content-Type**: Not defined
 - **Accept**: application/json

[[Back to top]](#) [[Back to API list]](../README.md#documentation-for-api-endpoints) [[Back to Model list]](../README.md#documentation-for-models) [[Back to README]](../README.md)

