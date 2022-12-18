//
//  BoardsFetcher.swift
//  Jira Sprint Reporter
//
//  Created by Jorrit van Asselt on 04/01/2022.
//

import Foundation

/// Exists to encapuate the paging behaviour of the jira api call to fetch
/// ALL the boards for the company.
class BoardsFetcher
{
    /// The projectIdentifier this instance was initialized with
    let cookieString: String
    
    private let session: URLSession
    
    /// Should only ever be accessed on the internal queue
    private var boards = [Board]()
    
    /// internal queue for serializing accesss to the 1 `boards` property
    /// while populating it with repeated network calls
    private let queue = DispatchQueue(label: "BoardsFetcher")
    
    init(cookieString: String,
         session: URLSession? = URLSession(configuration: .ephemeral))
    {
        self.cookieString = cookieString
        self.session = session ?? URLSession(configuration: .ephemeral)
    }
    
    func fetch(startAt: Int = 0) async -> [Board]?
    {
        let request = newRequest(startAt: startAt)
        do
        {
            let (data, response) = try await session.data(for: request)
            response.checkRateLimit()
            
            let decoder = JSONDecoder()
            let boardResults = try decoder.decode(BoardsResults.self,
                                                    from: data)
            
            /// serialize access to the mutable array `boards`
            queue.sync { self.boards.append(contentsOf: boardResults.values) }
            
            if !boardResults.isLast
            {
                // calling fetch again will append new results to the private
                // instance variable. Which is the variable we return once
                // we reach the last set, so no need to capture the return value
                // here.
                let _ = await fetch(startAt: boardResults.startAt)
            }
        }
        catch
        {
            print("Could not download data for \(request.url?.description ?? "no url in the request!"): \(error)")
        }
        return boards
    }
    
    private func newRequest(startAt: Int = 0) -> URLRequest
    {
        let urlString = "https://creativegroupdev.atlassian.net/rest/agile/1.0/board?startAt=\(startAt)"
        
        guard let url = URL(string: urlString)
        else { fatalError("Could not create URL from \(urlString)") }
        
        let request = URLRequest.jiraRequestWith(url: url, cookieString: cookieString)
        return request
    }
}
    
/// Typed representation of the JSON that jira api returns
struct BoardsResults: Decodable
{
    let maxResults: Int
    let startAt: Int
    let total: Int
    let isLast: Bool
    let values: [Board]
}

/// Typed representation of the board JSON that jira api returns
struct Board: Decodable, CustomStringConvertible
{
    var description: String
    {
        """
        name:\t\(name)
        type:\t\(type)
        id:\t\(id)
        \(location?.description ?? "")
        """
    }
    
    let id: Int
    let name: String
    let type: String
    
    let location: Location?
    struct Location: Decodable, CustomStringConvertible
    {
        let projectId: Int
        let displayName: String
        let projectName: String
        let projectKey: String
        let projectTypeKey: String
        let name: String
        var description: String
        {
            """
            display name:\t\(displayName)
            project name:\t\(projectName)
            name:\t\(name)
            """
        }
    }
}

