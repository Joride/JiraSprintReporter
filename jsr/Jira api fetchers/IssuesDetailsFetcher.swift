//
//  IssuesDetailsFetcher.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

/// Encapsulates all downloading and decoding details for issues (i.e. any
/// type of ticket with its own number in jira)
class IssuesDetailsFetcher
{
    private let session: URLSession
    
    /// The cookieString this instance was initialized with
    let cookieString: String
    
    /// The issueKeys this instance was initialized with
    let issueKeys: Set<String>
    
    init(issueKeys: Set<String>,
         cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral))
    {
        assert(!issueKeys.isEmpty)
        self.cookieString = cookieString
        self.issueKeys = issueKeys
        self.session = session ?? URLSession(configuration: .ephemeral)
    }
    func fetch() async -> [Issue]?
    {
        var keysString = ""
        let sortedKeys = issueKeys.sorted(by: { $0 > $1 } )
        for anIssueKey in sortedKeys
        {
            if anIssueKey == sortedKeys.last
            {
                keysString.append("\(anIssueKey)")
            }
            else
            {
                keysString.append("\(anIssueKey)%2C")
            }
        }
        
        let jqlQuery = "issuekey%20in%20(\(keysString))"
        let urlString = "https://creativegroupdev.atlassian.net/rest/api/3/search?jql=\(jqlQuery)"
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url, cookieString: cookieString)
        
        do
        {
            let (jsonData, response) = try await session.data(for: request)
            if let untilDate = response.rateLimitedUntil()
            {
                throw JiraApiError.rateLimited(untilDate)
            }
            do
            {
                let jiraIssues = try JSONDecoder().decode(JIRAIssues.self,
                                                    from: jsonData)
                return jiraIssues.issues

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

/// Typed representation of Issues JSON that the jira api returns
struct JIRAIssues: Decodable
{
    let issues: [Issue]
}
