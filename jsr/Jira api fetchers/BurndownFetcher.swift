//
//  BurndownFetcher.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

/// Encapsulates fetching and organizing the burndown of tickets for a sprint
/// within a project.
/// Note: this burndown is not the same as the burndown in Jira's web front-end:
/// tickets of any and all types are included in the burndown here, whereas in
/// jira only stories are shown.
class BurndownFetcher
{
    /// The sprintID with with this instance was initialized
    let sprint: Sprint
        
    /// The projectID with with this instance was initialized
    let projectID: Int
    
    /// The cookieString with with this instance was initialized
    let cookieString: String
    
    private let session: URLSession
    
    private func newRequest() -> URLRequest
    {
        let urlString = "https://creativegroupdev.atlassian.net/rest/greenhopper/1.0/rapid/charts/scopechangeburndownchart?rapidViewId=\(projectID)&sprintId=\(sprint.id)"
        
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url, cookieString: cookieString)
        return request
    }
    
    init(sprint: Sprint,
         projectID: Int,
         cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral))
    {
        self.sprint = sprint
        self.projectID = projectID
        self.cookieString = cookieString
        self.session = session ?? URLSession(configuration: .ephemeral)        
    }
    
    func fetch() async -> SprintIssueKeys?
    {
        let request = newRequest()
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
                decoder.dateDecodingStrategy = .millisecondsSince1970
                let burndownInfo = try decoder.decode(BurndownInfo.self,
                                                      from: jsonData)
                
                var commitment = Set<String>()
                var insertions = Set<String>()
                for aChangeInfoList in burndownInfo.changes.items
                {
                    for aChangeInfo in aChangeInfoList
                    {
                        // if this issue was added and that addition happened before or at the starttime of the
                        // sprint, this issue is part of the commitment (this includes ALL types, and the burn
                        // down chart in jira only shows a subset of type. Most notably, no sub tasks are shown in jira,
                        // but those WILL show up here
                        if (aChangeInfo.added ?? false)
                        {
                            
                            // - TODO: check if the issue was "closed", "delivered" etc before the sprint started?
                            if aChangeInfo.timestamp <= burndownInfo.startTime
                            {
                                // part of commitment
                                commitment.insert(aChangeInfo.key)
                            }
                            else
                            {
                                // part of insertions
                                insertions.insert(aChangeInfo.key)
                            }
                        }
                    }
                }
                let sprintIssueKeys = SprintIssueKeys(commitment: commitment,
                                                      insertions: insertions)
                return sprintIssueKeys
            }
            catch
            {
                print("Could not decode JSONData: \(error) \n\n\(String(data: jsonData, encoding: .utf8) ?? "❌")")
            }
        }
        catch
        {
            print("Could not download data for \(request.url?.description ?? "no url in the request!"): \(error)")
        }
        return nil
    }
}

/// Containering two sets of issues representing different things
struct SprintIssueKeys
{
    let commitment: Set<String>
    let insertions: Set<String>
}



/// Typed representation of the burndown JSON that the jira api returns
struct BurndownInfo: Decodable
{
    var startTime: Date
    var endTime: Date
    var changes: DecodedArray
}

/// Typed representation of the change concept in JSON that the jira api returns
struct Change: Decodable
{
    let key: String
    let column: Column?
    let added: Bool?
    struct Column: Decodable
    {
        let notDone: Bool?
        let done: Bool?
        let newStatus: String?
    }

    let timestamp: Date
    enum CodingKeys: CodingKey
    {
        case key
        case added
        case column
    }
    
    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let milliSecondsSince1970 = Double(container.codingPath[1].stringValue)!
        timestamp = Date(timeIntervalSince1970: milliSecondsSince1970/1000)
        key = try container.decode(String.self, forKey: CodingKeys.key)
        do
        {
            added = try container.decode(Bool?.self, forKey: CodingKeys.added)
        }
        catch { added = nil }
        
        do
        {
            column = try container.decode(Column?.self, forKey: CodingKeys.column)
        }
        catch { column = nil }
    }
}

/// Needed when JSON comes in that is a top-level array
struct DecodedArray: Decodable
{
    var items: [[Change]]
    
    // Defining DynamicCodingKeys type needed for creating
    // decoding container from JSONDecoder
    private struct DynamicCodingKeys: CodingKey
    {
        // Use for string-keyed dictionary
        var stringValue: String
        init?(stringValue: String)
        {
            self.stringValue = stringValue
        }

        // Use for integer-keyed dictionary
        var intValue: Int?
        init?(intValue: Int)
        {
            // We are not using this, thus just return nil
            return nil
        }
    }

    init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: DynamicCodingKeys.self)

        var tempArray = [[Change]]()
        for key in container.allKeys
        {
            let decodedObject = try container.decode([Change].self, forKey: DynamicCodingKeys(stringValue: key.stringValue)!)
            tempArray.append(decodedObject)
        }
        items = tempArray
    }
}

