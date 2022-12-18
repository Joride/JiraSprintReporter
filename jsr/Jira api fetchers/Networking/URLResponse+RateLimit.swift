//
//  URLResponse+RateLimit.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 17/12/2022.
//

import Foundation

extension URLResponse
{
    func checkRateLimit()
    {
        if let httpResponse = self as? HTTPURLResponse,
           let rateLimitResetTime = httpResponse.value(forHTTPHeaderField: "x-ratelimit-reset")
        {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mmZ" // derived from actual response
            formatter.locale = Locale.current
            
            print("Running into a rate limit set by Jira. Rate limited until \"\(rateLimitResetTime)\"")
            if let date = formatter.date(from: rateLimitResetTime)
            {
                let formatter = DateFormatter()
                formatter.locale = Locale.current
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                let dateString = formatter.string(from: date)
                print("In local time that is: \(dateString)")
                print("Exiting program now, take care.")
                exit(1)
            }
        }
    }
}
