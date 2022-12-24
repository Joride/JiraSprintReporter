//
//  URLResponse+RateLimit.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 17/12/2022.
//

import Foundation

enum JiraApiError: Error
{
    case rateLimited(Date?)
}
extension URLResponse
{
    /// Returns `true` if this application is now rate limited
    func rateLimitedUntil() -> Date?
    {
        /// see: https://developer.atlassian.com/cloud/jira/platform/rate-limiting/
        let rateLimiteStatusCode = 429
        if let httpResponse = self as? HTTPURLResponse
        {
            if rateLimiteStatusCode == httpResponse.statusCode
            {
                func printLocalizedDate(fromDate: Date)
                {
                    let formatter = DateFormatter()
                    formatter.locale = Locale.current
                    formatter.dateStyle = .medium
                    formatter.timeStyle = .short
                    let dateString = formatter.string(from: fromDate)
                    print("In local time that is: \(dateString)")
                }
                
                if let rateLimitResetTime = httpResponse.value(forHTTPHeaderField: "x-ratelimit-reset")
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ" // derived from actual response
                    formatter.locale = Locale.current
                    
                    print("Running into a rate limit set by Jira. Rate limited until \"\(rateLimitResetTime)\"")
                    if let date = formatter.date(from: rateLimitResetTime)
                    {
                        printLocalizedDate(fromDate: date)
                        return date
                    }
                }
                if let retryTime = httpResponse.value(forHTTPHeaderField: "Retry-After")
                {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ" // derived from actual response
                    formatter.locale = Locale.current
                    
                    print("Running into a rate limit set by Jira. Rate limited for \(retryTime) seconds")
                    if let timeInterval = TimeInterval(retryTime)
                    {
                        let date = Date().addingTimeInterval(timeInterval)
                        printLocalizedDate(fromDate: date)
                        return date
                    }
                }
                
                print("Jira api returned \(rateLimiteStatusCode), indicating a rate limit. Not possible to acquire until when though.")
                // educated guess based on the experience during development
                // of this application. Usually it is 2-4 minutes tops
                return Date().addingTimeInterval(4 * 60) 
            }
        }
        return nil
    }
}
