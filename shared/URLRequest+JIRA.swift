//
//  URLRequest+JIRA.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

extension URLRequest
{
    static func jiraRequestWith(url: URL, cookieString: String) -> URLRequest
    {
        var request = URLRequest(url: url)
        request.addValue(cookieString, forHTTPHeaderField: "Cookie")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept")
        request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        request.addValue("keep-alive", forHTTPHeaderField: "Connection")
        return request
    }
}

