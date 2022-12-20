//
//  IssuesChangelogsFetcher.swift
//  jsn
//
//  Created by Jorrit van Asselt on 19/12/2022.
//

import Cocoa

class IssuesChangelogsFetcher: NSObject
{
    /// The projectIdentifier this instance was initialized with
    let cookieString: String
    
    let issueKeys: [String]
    
    /// internal queue for serializing accesss to the 1 `issues` property
    /// while populating it with repeated network calls
    private let queue = DispatchQueue(label: "IssuesChangelogsFetcher")
    
    /// Should only ever be accessed on the internal queue
    private var issues = [Issue]()
    
    private let session: URLSession
    
    /// example: "2021-11-18T11:01:18.363-0800"
    private let JIRAIssueDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
                                    //"2022-12-19T18:01:36.847+0100"
    
    @Sendable private func decodeDate(_ decoder: Decoder) throws -> Date
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
    
    init(issueKeys: [String],
        cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral))
    {
        self.issueKeys = issueKeys
        self.cookieString = cookieString
        self.session = session ?? URLSession(configuration: .ephemeral)
    }
    
    func fetch() async throws -> [ExtendedIssue]
    {
        let extendedIssues = try await withThrowingTaskGroup(of: ExtendedIssue.self) { group in
            
            for anIssueKey in issueKeys
            {
                group.addTask { try await self.fetch(issueKey: anIssueKey) }
            }
            
            var result = [ExtendedIssue]()
            for try await extendedIssue in group
            {
                result.append(extendedIssue)
            }
            return result
        }
        return extendedIssues
    }
    
    private func fetch(issueKey: String) async throws -> ExtendedIssue
    {
        let urlString = "https://creativegroupdev.atlassian.net/rest/api/2/issue/\(issueKey)?expand=changelog"
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url, cookieString: cookieString)
        
        let (data, response) = try await session.data(for: request)
        response.checkRateLimit()
        
        do
        {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom(self.decodeDate)
            let issue = try decoder.decode(ExtendedIssue.self,
                                           from: data)
            return issue
        }
        catch
        {
            print("Error decoding json for \(issueKey) \"\(url)\": \(error)")
            throw error
        }
    }
}


/// Issues
struct ExtendedIssue: Decodable
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

extension ExtendedIssue
{
    /// is the issue is not Done /  completed, this function will return nil
    func doneDate() -> Date?
    {
        guard let state = fields.status?.state
        else { fatalError("Ticket without state encountered! This is unexpected and should be reviewed.") }
        
        if state == .unexpected { fatalError("Ticket with unexpected state encountered! This is unexpected and should be reviewed.") }
        
        /// if the ticket is closed, the close date is returned
        /// if the tickets is released under split we return that date
        var closedDate: Date? = nil
        var releasedUnderSplitDate: Date? = nil
        if let histories = changelog?.histories
        {
            for aHistory in histories
            {
                for aChange in aHistory.items
                {
                    if aChange.field == "status" || aChange.field == "Status"
                    {
                        if aChange.toString == Fields.Status.State.closed.rawValue ||
                            aChange.toString == Fields.Status.State.done.rawValue
                        {
                            closedDate = aHistory.created
                        }
                    }
                }
            }
        }
        
        if nil != closedDate && nil != releasedUnderSplitDate
        {
            return closedDate! > releasedUnderSplitDate! ? closedDate! : releasedUnderSplitDate!
        }
        if nil != closedDate { return closedDate }
        if nil != releasedUnderSplitDate { return releasedUnderSplitDate }
        
        return nil
    }
}
