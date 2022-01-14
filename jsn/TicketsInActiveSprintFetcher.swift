//
//  TicketsInActiveSprintFetcher.swift
//  jsn
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

class DoneTicketsInActiveSprintFetcher
{
    let cookieString: String
    
    private let session: URLSession
    
    /// The projectKey with with this instance was initialized
    let projectKey: String
    
    init(projectKey: String,
         cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral),
         fetchResult: @escaping ([Issue]?) -> (Void))
    {
        self.projectKey = projectKey
        self.cookieString = cookieString
        self.session = session ?? URLSession(configuration: .ephemeral)
        fetch(result: fetchResult)
    }
    
    private func fetch(result: @escaping ([Issue]?) -> (Void))
    {
//        let jqlQuery = "project%20=%20\(projectKey)%20AND%20Sprint%20=%201842"
        let jqlQuery = "project%20=%20\(projectKey)%20AND%20Sprint%20in%20openSprints()%20and%20type%20!=%20Sub-task"
//        let jqlQuery = "project%20=%20\(projectKey)%20AND%20Sprint%20in%20openSprints()%20and%20status=Closed"
        let urlString = "https://tripactions.atlassian.net/rest/api/3/search?jql=\(jqlQuery)"
        
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url,
                                                 cookieString: cookieString)
        
        let task = session.dataTask(with: request) { (data: Data?,
                                                      response: URLResponse?,
                                                      error: Error?) in
            if let error = error
            {
                print("Could not get tickets: \(error)")
            }
            else
            {
                guard let jsonData = data
                else { fatalError("No error, but no data or no response either. HUH?") }

                do
                {
                    let jiraIssues = try JSONDecoder().decode(SprintTickets.self,
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


struct SprintTickets: Decodable
{
    let startAt: Int
    let maxResults: Int
    let total: Int
    let issues: [Issue]
}

