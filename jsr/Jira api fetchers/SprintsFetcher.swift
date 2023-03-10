//
//  SprintsFetcher.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

/// Encapsulates fetching and decoding general (i.e. no details) information
/// on all sprints that exist for the given projectIdentifier.
class SprintsFetcher
{
    /// The projectIdentifier this instance was initialized with
    let projectIdentifier: Int
    
    /// The projectIdentifier this instance was initialized with
    let cookieString: String
    
    private let session: URLSession
    
    /// Should only ever be accessed on the internal queue
    private var sprints = [Sprint]()
    
    /// internal queue for serializing accesss to the 1 `sprints` property
    /// while populating it with repeated network calls
    private let queue = DispatchQueue(label: "SprintsFetcher")
    
    private let JIRASprintDateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
    private var dateFormatter: DateFormatter
    {
        let formatter = DateFormatter()
        formatter.dateFormat = JIRASprintDateFormat
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }
    
    private func newRequest(startAt: Int) -> URLRequest
    {
        let urlString = "https://creativegroupdev.atlassian.net/rest/agile/1.0/board/\(projectIdentifier)/sprint?startAt=\(startAt)"
        
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url, cookieString: cookieString)
        return request
    }

    init(projectIdentifier: Int,
         cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral))
    {
        self.projectIdentifier = projectIdentifier
        self.cookieString = cookieString
        self.session = session ?? URLSession(configuration: .ephemeral)
    }
    func fetch(startAt: Int = 0) async -> [Sprint]
    {
        let request = newRequest(startAt: startAt)
        do
        {
            let (jsonData, response) = try await session.data(for: request)
            if let untilDate = response.rateLimitedUntil()
            {
                throw JiraApiError.rateLimited(untilDate)
            }
            
            do
            {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .custom(self.decodeDate)
                let sprintResults = try decoder.decode(SprintsResults.self,
                                                        from: jsonData)
                
                queue.sync { self.sprints.append(contentsOf: sprintResults.values) }
                
                /// Since the total is unknown, this here cannot be optimized
                /// by doing the network calls in parallel.
                if !sprintResults.isLast
                {
                    let _ = await fetch(startAt: sprints.count)
                }
            }
            catch
            {
                print("Could not decode JSONData: \(error) \n\n\(String(data: jsonData, encoding: .utf8) ?? "???")")
            }
        }
        catch
        {
            print("Could not download data for \(request.url?.description ?? "no url in the request!"): \(error)")
        }
        return sprints
    }
    
    private enum DateDecoderError: Error
    {
        case dateFormatterFailed
    }
    
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
}

/// Typed representation of the JSON that jira api returns
struct SprintsResults: Decodable
{
    let maxResults: Int
    let startAt: Int
    let isLast: Bool
    
    let values: [Sprint]
}

/// Typed representation of the Sprint JSON that the jira api returns
struct Sprint: Decodable
{
    enum State: String
    {
        case active = "active"
        case closed = "closed"
        case future = "future"
        case unexpected
        
        init?(rawValue: String)
        {
            switch rawValue
            {
            case State.active.rawValue: self = .active
            case State.closed.rawValue: self = .closed
            case State.future.rawValue: self = .future
            default:
                self = .unexpected
                fatalError("Unexpected Sprint State encountered. This needs to be properly handled")
            }
        }
    }
    var status: State { State(rawValue: state) ?? .unexpected }
    let id: Int
    let state: String
    let name: String?
    let startDate: Date?
    let endDate: Date?
    let completeDate: Date?
    let goal: String?
}

