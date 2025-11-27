import Foundation

let sharedConfig: URLSessionConfiguration = {
    let config = URLSessionConfiguration.default
    
    // MARK: - Timeout Configuration
    // Request timeout: max time between successive data packets
    config.timeoutIntervalForRequest = 30.0  // Reduced from 60s - government APIs should respond faster
    
    // Resource timeout: total time for entire request/response (critical for CSV downloads)
    config.timeoutIntervalForResource = 120.0  // 2 minutes max for large CSV files
    
    // MARK: - Connectivity & Retry Behavior
    // Wait for connectivity instead of failing immediately (crucial for outdoor mobile use)
    config.waitsForConnectivity = true
    
    // MARK: - Cache Policy
    // Configure cache size (20MB memory, 100MB disk)
    // Government gauge data changes frequently, so smaller memory cache
    let cache = URLCache(
        memoryCapacity: 20 * 1024 * 1024,   // 20 MB
        diskCapacity: 100 * 1024 * 1024,     // 100 MB
        diskPath: "gauge_drivers_cache"
    )
    config.urlCache = cache
    
    // MARK: - Connection Management
    
    // Allow connections over cellular (users often check river gauges outdoors)
    config.allowsCellularAccess = true
        
    // Allow constrained networks (low data mode)
    config.allowsConstrainedNetworkAccess = true
    
    // MARK: - HTTP Behavior
    // Enable HTTP pipelining for better performance
    config.httpShouldUsePipelining = true
    
    // Set cookies policy (APIs likely don't use cookies, but be explicit)
    config.httpCookieAcceptPolicy = .never
    config.httpShouldSetCookies = false
    
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    // MARK: - Headers
    // Set User-Agent to identify your app (some APIs may require this)
    config.httpAdditionalHeaders = [
        "User-Agent": "GaugeWatcher/\(appVersion) (iOS/macOS; github.com/drewalth/gauge-watcher)",
        "Accept": "application/json, text/csv, text/plain",
        "Accept-Encoding": "gzip, deflate"
    ]
    
    // MARK: - TLS & Security
    // Use TLS 1.2+ (should be default, but be explicit)
    config.tlsMinimumSupportedProtocolVersion = .TLSv12
    
    // MARK: - Background Configuration (if needed later)
    // Set to false for foreground-only requests (modify if you add background refresh)
    config.isDiscretionary = false
    config.sessionSendsLaunchEvents = false
    
    return config
}()

let sharedSession = URLSession(configuration: sharedConfig)
