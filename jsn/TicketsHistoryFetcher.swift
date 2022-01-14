//
//  TicketsHistoryFetcher.swift
//  jsn
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

class TicketsHistoryFetcher
{
    private let resultsHandler: ([JIRAIssue]) -> (Void)
    
    /// MUST always be accessed from serialQueue
    private var issues: [JIRAIssue] = []
    
    init(issueKeys: [String],
         cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral),
         fetchResult: @escaping ([JIRAIssue]) -> (Void))
    {
        self.resultsHandler = fetchResult
        self.cookieString = cookieString
        self.issueKeys = issueKeys
        self.session = session ?? URLSession(configuration: .ephemeral)
        
        for index in 0 ..< issueKeys.count
        {
            concurrentQueue.async
            {
                self.fetch(issueKeyIndex: index)
            }
        }
    }
    
    private let serialQueue = DispatchQueue(label: "TicketsHistoryFetcher-serial")
    private let concurrentQueue = DispatchQueue(label: "TicketsHistoryFetcher-serial",
                                        attributes: .concurrent)
    
    private let session: URLSession
    
    /// The cookieString this instance was initialized with
    let cookieString: String
    
    /// The issueKeys this instance was initialized with
    let issueKeys: [String]
    
    /// example: "2021-11-18T11:01:18.363-0800"
    private let JIRAIssueDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    
    private var dateFormatter: DateFormatter
    {
        let formatter = DateFormatter()
        formatter.dateFormat = JIRAIssueDateFormat
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    private enum DateDecoderError: Error
    {
        case dateFormatterFailed
    }
    
    private func decodeDate(_ decoder: Decoder) throws -> Date
    {
        let dateString = try decoder.singleValueContainer().decode(String.self)
        
        if let date = dateFormatter.date(from: dateString)
        {
            return date
        }
        else
        {
            /// Did the API return a datestring in an unexpected format?
            /// see propert `JIRASprintDateFormat` on this class
            throw(DateDecoderError.dateFormatterFailed)
        }
    }
    private func fetch(issueKeyIndex: Int)
    {
        let ticketKey = issueKeys[issueKeyIndex]
        let urlString = "https://tripactions.atlassian.net/rest/api/2/issue/\(ticketKey)?expand=changelog"
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url, cookieString: cookieString)
        
        let task = session.dataTask(with: request) { (data: Data?,
                                                      response: URLResponse?,
                                                      error: Error?) in
            if let error = error
            {
                print("Could not download ticket info: \(error)")
            }
            else
            {
                guard let jsonData = data
                else { fatalError("No error, but no data or no response either. HUH?") }
                do
                {
                    let decoder = JSONDecoder()
                    decoder.dateDecodingStrategy = .custom(self.decodeDate)
                    let jiraIssue = try decoder.decode(JIRAIssue.self,
                                                       from: jsonData)
                    
                    self.serialQueue.async
                    {
                        self.issues.append(jiraIssue)
                        if self.issues.count == self.issueKeys.count
                        {
                            self.resultsHandler(self.issues)
                        }
                    }
                }
                catch
                {
                    print("Could not decode JSONData: \(error)")
                }
            }
        }
        let _ = task.resume()
    }
}

/// Issues
struct JIRAIssue: Decodable
{
    let id: String
    let key: String
    let changelog : Changelog?
    let fields : Fields
}
struct Changelog: Decodable
{
    let startAt: Int
    let maxResults: Int
    let total: Int
    let histories: [IssueHistory]?
    struct IssueHistory: Decodable
    {
        let created: Date
        let author: IssueChangeAuthor?
        struct IssueChangeAuthor: Decodable
        {
            let emailAddress: String?
            let displayName: String
        }
        let items: [IssueChange]
        struct IssueChange: Decodable
        {
            let field: String
            let fromString: String?
            let toString: String?
        }
    }
}
