//
//  SprintSummaryFetcher.swift
//  jsn
//
//  Created by Jorrit van Asselt on 21/12/2022.
//

import Foundation

class SprintSummaryFetcher: NSObject
{
    /// The projectIdentifier this instance was initialized with
    let cookieString: String
    
    let sprintID: Int
    
    private let session: URLSession
    
    init(sprintID: Int,
         cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral))
    {
        self.sprintID = sprintID
        self.cookieString = cookieString
        self.session = session ?? URLSession(configuration: .ephemeral)
    }
    
    func fetch() async throws -> SprintSummary
    {
        let urlString = "https://creativegroupdev.atlassian.net/rest/agile/1.0/sprint/\(sprintID)"
           
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url,
                                                 cookieString: cookieString)
        do
        {
            let (data, response) = try await session.data(for: request)
            if let untilDate = response.rateLimitedUntil()
            {
                throw JiraApiError.rateLimited(untilDate)
            }
            
            let decoder = JSONDecoder()
            let sprintSummary = try decoder.decode(SprintSummary.self,
                                                   from: data)
            return sprintSummary
            
        }
        catch
        {
//            print("Could not download sprint summary \(request.url?.description ?? "no url in the request!"): \(error)")
            throw error
        }
    }
}

struct SprintSummary: Decodable
{
    let id: Int
    let url: String
    let state: String
    let name: String
    let originBoardId: Int
    let goal: String
    
    enum CodingKeys: String, CodingKey
    {
        case id
        case url = "self"
        case state
        case name
        case originBoardId
        case goal
    }
}
