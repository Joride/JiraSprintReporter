//
//  IssuesDetailsFetcher.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

class IssuesDetailsFetcher
{
    init(issueKeys: Set<String>,
         cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral),
         fetchResult: @escaping ([Issue]?) -> (Void))
    {
        assert(!issueKeys.isEmpty)
        self.cookieString = cookieString
        self.issueKeys = issueKeys
        self.session = session ?? URLSession(configuration: .ephemeral)
        fetch(result: fetchResult)
    }
    private let session: URLSession
    
    /// The cookieString this instance was initialized with
    let cookieString: String
    
    /// The issueKeys this instance was initialized with
    let issueKeys: Set<String>
        
    private func fetch(result: @escaping ([Issue]?) -> (Void))
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
        let urlString = "https://tripactions.atlassian.net/rest/api/3/search?jql=\(jqlQuery)"
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
                    let jiraIssues = try JSONDecoder().decode(JIRAIssues.self,
                                                        from: jsonData)
                      
                    result(jiraIssues.issues)

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
struct JIRAIssues: Decodable
{
    let issues: [Issue]
}
